// StellarCoop's native part, loaded by its Lua script (package.loadlib). It links two players over Steam, through the
// Steamworks API the game loaded and started (never its own SteamAPI_Init); the logic lives in link/core.h, this file
// is the Windows side: Steam's callbacks, the worker thread, files and fault containment.
// Lua asks through coop-request.txt; this part answers in coop-status.txt, appends numbered UTC events to
// coop-link.log (the previous run's is coop-link.old.log) and writes coop-report.txt on 'coop report', all in the mod
// folder. One worker thread makes every Steam call; the game's Steam callback thread only stores atomics. The worker
// also carries the shared fight's channel 2 (Phase 11) between the link and the job's mailbox (glue/tick.cpp), the
// shared quests' lines on the same channel (Phase 12, glue/tick.cpp) with their record beside each co-op slot, the
// synced photo mode between Lua's coop-state.txt, the link's photo line and the game thread's pause (glue/tick.cpp),
// the chat and vitals lines between the link, our EVE (glue/tick.cpp) and Lua's two short-lived chat files,
// Night Operation's line from Lua's coop-night.txt to the link (hers comes back in the status), the race lines Lua
// writes into coop-race.txt and coop gift's lines from Lua's gift requests (hers of both reach Lua through
// coop-chat.txt). It
// makes the co-op save copies at the title and switches the game's save name to them on request (save/twins.h), and
// puts our join code on the clipboard on the copy request (glue/clipboard.h). The follow's camps lines go through the
// link (link/core.h), its travel request to the game thread (glue/tick.cpp).
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <algorithm>
#include <atomic>
#include <cstdint>
#include <map>
#include <memory>
#include <string>
#include <vector>

#include "game/pak_list.h"
#include "glue/clipboard.h"
#include "glue/tick.h"
#include "link/core.h"
#include "save/shortcut_load.h" // kSlot
#include "save/slot.h"
#include "save/twins.h"
#include "save/watch.h"

#ifndef STELLARCOOP_VERSION
#define STELLARCOOP_VERSION "dev"
#endif

namespace coop::pose {
// Shared with the pose path (glue/tick.h): binary-safe, for the recording too.
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
} // namespace coop::pose

namespace {
using coop::pose::write_text;
std::wstring folder;           // This DLL's folder, with its trailing separator.
wchar_t log_path[MAX_PATH];    // coop-link.log, kept for the last line written at process exit.
// The chat's two files (UI-DESIGN 5.2) and their temporaries: coop-say.txt, Lua's typed line, taken at every pass;
// coop-chat.txt, our lines for Lua, written only while Lua has taken the last. Each lives about 250 ms at most. Beside
// them coop-race.txt, Lua's race lines, taken at every pass too. All six are deleted at worker start, when a chat
// session ends, and at process exit (so kept for DllMain).
wchar_t chat_files[6][MAX_PATH];
void delete_chat() {
  for (const wchar_t *path : chat_files)
    DeleteFileW(path);
}
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
std::wstring wide(const std::string &text) {
  int n = MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), nullptr, 0);
  std::wstring out(static_cast<size_t>(n > 0 ? n : 0), L'\0');
  if (n > 0)
    MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), out.data(), n);
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

// The whole file (its first max bytes), then deleted; empty when there is none, or when it cannot be deleted (Lua's
// busy check holds it open, say): taken at a later pass, never twice. Lua writes it beside and renames it, so it is
// complete. 512 by default: a chat line or a night line (link/protocol.h's kMaxNight) and its line end; a request takes
// link/protocol.h's kMaxRequestFile.
// Deleted on close, not by path after it: a request Lua renames in once the handle is closed is never deleted unread.
std::string take_text(const std::wstring &path, DWORD max = 512) {
  HANDLE f = CreateFileW(path.c_str(), GENERIC_READ | DELETE, 0, nullptr, OPEN_EXISTING, FILE_FLAG_DELETE_ON_CLOSE,
                         nullptr);
  if (f == INVALID_HANDLE_VALUE)
    return {};
  std::string text(max, '\0');
  DWORD n = 0;
  bool ok = ReadFile(f, text.data(), max, &n, nullptr);
  CloseHandle(f);
  if (!ok)
    return {};
  text.resize(n);
  return text;
}
// coop-race.txt: Lua's queue holds 512 lines at most (core/link.lua), each shorter than kMaxMessage.
constexpr DWORD kRaceFile = 512 * coop::kMaxMessage;

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
std::wstring saves_dir;   // %LOCALAPPDATA%\SB\Saved\SaveGames, or empty.
std::wstring backups_dir; // %LOCALAPPDATA%\SB\Saved\StellarCoopBackups (outside the synced folder), or empty.
void write_header() {
  LARGE_INTEGER counter;
  QueryPerformanceCounter(&counter);
  char run[16];
  wsprintfA(run, "%08lx", static_cast<unsigned long>(counter.LowPart ^ (GetCurrentProcessId() << 16)));
  wchar_t local[MAX_PATH];
  DWORD n = GetEnvironmentVariableW(L"LOCALAPPDATA", local, MAX_PATH);
  if (n && n < MAX_PATH) {
    saves_dir = std::wstring(local, n) + L"\\SB\\Saved\\SaveGames";
    backups_dir = std::wstring(local, n) + L"\\SB\\Saved\\StellarCoopBackups";
  }
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

// The save watcher: every 5 s, the name, size and write time of every file under the save folder (never opened), and
// this account's co-op marker (the only file there that is read).
coop::SaveWatch save_watch;
uint64_t next_save_watch = 0;
int coop_marker = coop::slot::kNotRead; // StellarCoopSlot.txt's slot, kNone or kBad, once the SteamID is known.
int slot_index = coop::slot::kUnread;   // The slot the game entered, every 250 ms (pose::loaded_slot).
coop::slot::Saves saves_state = coop::slot::Saves::unread; // The save files the game uses, with it (pose::saves).
uint64_t next_slot = 0;
bool probed = false; // The save name's probe ran at load.
// The files under dir, in folders down to deepest levels below it, most of them at most.
void list_saves(const std::wstring &dir, const std::string &prefix, std::vector<coop::SaveWatch::Entry> &out, int depth,
                int deepest = 3, size_t most = SIZE_MAX) {
  WIN32_FIND_DATAW f;
  HANDLE h = FindFirstFileW((dir + L"\\*").c_str(), &f);
  if (h == INVALID_HANDLE_VALUE)
    return;
  do {
    std::wstring name = f.cFileName;
    if (name == L"." || name == L"..")
      continue;
    if (out.size() >= most)
      break;
    std::string rel = prefix + utf8(name);
    if (f.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
      if (depth < deepest)
        list_saves(dir + L"\\" + name, rel + "\\", out, depth + 1, deepest, most);
    } else {
      out.push_back({rel, (uint64_t(f.nFileSizeHigh) << 32) | f.nFileSizeLow,
                     (uint64_t(f.ftLastWriteTime.dwHighDateTime) << 32) | f.ftLastWriteTime.dwLowDateTime});
    }
  } while (FindNextFileW(h, &f));
  FindClose(h);
}

// The .pak mods the game loads beyond the base game's (game/pak_list.h), from SB\Content\Paks next to the exe's
// SB\Binaries\Win64 and its folders 8 levels down (4096 files at most; the engine mounts paks at any depth), read once
// at start: a header line names them, and each friend gets their count and hash, and our mod containers by name. The
// CNS packs among the files (.dekcns.json under ~mods, kMaxCnsPacks read, kMaxCnsBytes each) are counted with their
// outfits for the log and the status's cns= line, and the assets they declare (cns_assets) go to coop-cns.txt, a
// "<path> <outfit>" line each, sorted, written at every start (empty without CNS packs): the only paths of a mod
// partner/puppet.lua loads when a friend's table names one, and the outfits partner/capture.lua tags her parts with.
coop::Paks game_paks;
std::vector<coop::PakMod> game_mods;
std::string cns_line; // "cns=<packs> <outfits>\n", or empty without CNS packs.
void log_paks() {
  wchar_t exe[MAX_PATH];
  DWORD n = GetModuleFileNameW(nullptr, exe, MAX_PATH);
  std::wstring dir(exe, n && n < MAX_PATH ? n : 0);
  for (int up = 0; up < 3; ++up) // The exe's name, Win64, Binaries.
    dir.resize(dir.find_last_of(L"\\/") == std::wstring::npos ? 0 : dir.find_last_of(L"\\/"));
  std::vector<coop::SaveWatch::Entry> files;
  if (!dir.empty())
    list_saves(dir + L"\\Content\\Paks", "", files, 0, 8, 4096);
  std::vector<coop::PakFile> paks;
  size_t packs = 0;
  uint64_t outfits = 0;
  std::map<std::string, std::string> assets;
  for (auto &f : files) {
    paks.push_back({f.name, f.size});
    if (packs < coop::kMaxCnsPacks && coop::cns_pack(f.name)) {
      bool exists = false;
      ++packs;
      const std::string json =
          coop::pose::read_file(dir + L"\\Content\\Paks\\" + wide(f.name), exists, coop::kMaxCnsBytes);
      outfits += coop::cns_outfits(json);
      coop::cns_assets(json, assets);
    }
  }
  std::string declared;
  for (const auto &[path, fit] : assets)
    declared += path + " " + fit + "\n";
  write_text(folder + L"coop-cns.txt", declared);
  game_paks = coop::digest(paks);
  game_mods = coop::mods(paks);
  std::string names = game_paks.names.size() > 1000 ? game_paks.names.substr(0, 1000) + "..." : game_paks.names;
  header_lines.push_back("paks " + std::to_string(game_paks.count) + " beyond the base game, hash " +
                         std::to_string(game_paks.hash) + (names.empty() ? "" : ": " + names));
  append(utc_stamp() + " " + header_lines.back());
  if (packs) {
    cns_line = "cns=" + std::to_string(packs) + " " + std::to_string(outfits) + "\n";
    header_lines.push_back("cns " + std::to_string(packs) + " packs, " + std::to_string(outfits) + " outfits, " +
                           std::to_string(assets.size()) + " assets");
    append(utc_stamp() + " " + header_lines.back());
  }
}

// steam_id: 0 until Steam is ready; the marker is then not looked up, as another account's folder never decides.
void watch_saves(uint64_t now_ms, uint64_t steam_id) {
  if (saves_dir.empty() || now_ms < next_save_watch)
    return;
  next_save_watch = now_ms + 5000;
  std::vector<coop::SaveWatch::Entry> files;
  list_saves(saves_dir, "", files, 0);
  for (auto &line : save_watch.update(files, utc_stamp()))
    append(line);
  if (steam_id) {
    bool exists = false;
    std::string text = coop::pose::read_file(saves_dir + L"\\" + std::to_wstring(steam_id) + L"\\StellarCoopSlot.txt",
                                             exists, coop::slot::kMaxMarker + 1);
    coop_marker = exists ? coop::slot::marker(text) : coop::slot::kNone;
  }
}

// The co-op saves' file functions (save/twins.h): names in this account's save folder, and in a new folder of the
// backups' folder. Reads share everything, so the game's own writes are never blocked; writes are flushed before
// their rename.
class WinFs {
public:
  WinFs(const std::wstring &dir, const std::wstring &backups) : dir_(dir + L"\\"), backups_(backups) {}
  coop::twins::Stat stat(const std::string &name) {
    WIN32_FILE_ATTRIBUTE_DATA a;
    if (!GetFileAttributesExW((dir_ + wide(name)).c_str(), GetFileExInfoStandard, &a) ||
        (a.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY))
      return {};
    return {true, (uint64_t(a.nFileSizeHigh) << 32) | a.nFileSizeLow,
            (uint64_t(a.ftLastWriteTime.dwHighDateTime) << 32) | a.ftLastWriteTime.dwLowDateTime};
  }
  bool read(const std::string &name, std::string &out, size_t max) { return read_at(dir_ + wide(name), out, max); }
  bool write(const std::string &name, const std::string &bytes) { return write_at(dir_ + wide(name), bytes); }
  bool rename(const std::string &from, const std::string &to) {
    return MoveFileExW((dir_ + wide(from)).c_str(), (dir_ + wide(to)).c_str(),
                       MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH);
  }
  bool remove(const std::string &name) { return DeleteFileW((dir_ + wide(name)).c_str()); }
  std::vector<std::string> list() {
    std::vector<std::string> names;
    WIN32_FIND_DATAW f;
    HANDLE h = FindFirstFileW((dir_ + L"*").c_str(), &f);
    if (h == INVALID_HANDLE_VALUE)
      return names;
    do {
      if (!(f.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY))
        names.push_back(utf8(f.cFileName));
    } while (FindNextFileW(h, &f));
    FindClose(h);
    return names;
  }
  // StellarCoopBackups\<UTC time>[-n]\, new; its path, or empty.
  std::string backup_dir() {
    current_.clear();
    if (backups_.empty())
      return {};
    CreateDirectoryW(backups_.c_str(), nullptr); // Already there after the first backup.
    SYSTEMTIME t;
    GetSystemTime(&t);
    wchar_t stamp[24];
    wsprintfW(stamp, L"%04u%02u%02uT%02u%02u%02uZ", t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond);
    for (int n = 0; n < 100; ++n) {
      const std::wstring path = backups_ + L"\\" + stamp + (n ? L"-" + std::to_wstring(n) : std::wstring());
      if (CreateDirectoryW(path.c_str(), nullptr)) {
        current_ = path + L"\\";
        return utf8(path);
      }
      if (GetLastError() != ERROR_ALREADY_EXISTS)
        return {};
    }
    return {};
  }
  // Written beside as .coop-tmp, then renamed: a full disk or a killed game never leaves a cut .sav in the backup.
  bool backup_write(const std::string &name, const std::string &bytes) {
    if (current_.empty())
      return false;
    const std::wstring path = current_ + wide(name), temp = path + L".coop-tmp";
    if (write_at(temp, bytes) && MoveFileExW(temp.c_str(), path.c_str(), MOVEFILE_WRITE_THROUGH))
      return true;
    DeleteFileW(temp.c_str());
    return false;
  }
  bool backup_read(const std::string &name, std::string &out, size_t max) {
    return !current_.empty() && read_at(current_ + wide(name), out, max);
  }

private:
  static bool read_at(const std::wstring &path, std::string &out, size_t max) {
    HANDLE f = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
                           OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (f == INVALID_HANDLE_VALUE)
      return false;
    LARGE_INTEGER size;
    bool ok = GetFileSizeEx(f, &size) && size.QuadPart >= 0 && uint64_t(size.QuadPart) <= max;
    if (ok) {
      out.resize(static_cast<size_t>(size.QuadPart));
      for (size_t at = 0; ok && at < out.size();) {
        DWORD n = 0;
        ok = ReadFile(f, out.data() + at, static_cast<DWORD>(std::min<size_t>(out.size() - at, 1 << 20)), &n,
                      nullptr) &&
             n;
        at += n;
      }
    }
    CloseHandle(f);
    return ok;
  }
  static bool write_at(const std::wstring &path, const std::string &bytes) {
    HANDLE f = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (f == INVALID_HANDLE_VALUE)
      return false;
    bool ok = true;
    for (size_t at = 0; ok && at < bytes.size();) {
      DWORD n = 0;
      ok = WriteFile(f, bytes.data() + at, static_cast<DWORD>(std::min<size_t>(bytes.size() - at, 1 << 20)), &n,
                     nullptr) &&
           n;
      at += n;
    }
    ok = FlushFileBuffers(f) && ok;
    CloseHandle(f);
    return ok;
  }
  std::wstring dir_, backups_, current_;
};

coop::Api api;
std::unique_ptr<coop::Link> link;
bool chat_was = false;    // A chat session held at the last pass.
uint64_t next_vitals = 0; // Our vitals are read every 100 ms in a chat session (500 after a read over 1 ms).
bool switched_off = false; // coop off: until the game restarts, only coop status and coop report get an answer.
std::wstring command_line;
bool loaded = false, streaming = false; // streaming: the loopback, a recording, a replay or a friend: a pass each 5 ms.
std::string written;

// The co-op saves (save/twins.h): this account's file functions once the SteamID is known, and the requests and
// passes, against the game as glue/tick.cpp reads it.
std::unique_ptr<WinFs> account;
coop::twins::Switch coop_saves;
// The shared quests' record beside co-op slot n (StellarCoopQuests0N.txt), through save/twins.h's name check and put.
const coop::pose::QuestFiles quest_files{
    [](int slot, std::string &text, size_t max) {
      text.clear();
      const std::string name = coop::twins::quests_name(slot);
      return account && (!account->stat(name).exists || account->read(name, text, max));
    },
    [](int slot, const std::string &text) {
      return account && coop::twins::put(*account, coop::twins::quests_name(slot), text);
    }};
struct GameView {
  coop::slot::Saves saves() { return saves_state; }
  std::string why() { return coop::pose::saves_why(); }
  bool world() { return coop::pose::lua_state().world; }
  bool title() { return coop::pose::lua_state().title; }
  int load_mode() { return coop::pose::load_mode(); }
  std::string swap(bool coop) {
    std::string why = coop::pose::saves_switch(coop);
    saves_state = coop::pose::saves(); // The status shows the switch at once.
    return why;
  }
};

std::string status_text() {
  std::string head = link ? link->status(coop::Counters{cb333.load(), cb505.load(), cb1251.load()})
                          : "mod=" + coop::token(STELLARCOOP_VERSION) + " proto=" +
                                std::to_string(coop::kProtocol) + " steam=waiting\n";
  return head + cns_line + coop::pose::status() + "\n" +
         coop::slot::line(slot_index, coop_marker, coop::pose::lua_state().world, saves_state) + "\n" +
         coop_saves.status() + "\n" + coop::pose::fight_status() + "\n" + coop::pose::pilot_status() + "\n" +
         coop::pose::rows_status() + "\n" +
         coop::pose::quest_status() + (link ? link->photo_status(coop::pose::frozen()) + "\n" : std::string()) +
         "last=" + journal.last() + "\n";
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
      link = std::make_unique<coop::Link>(api, STELLARCOOP_VERSION, event,
                                          [](const uint8_t *d, size_t n) { coop::pose::peer_receive(d, n); });
      link->paks(game_paks.count, game_paks.hash, game_mods);
    }
    if (loaded && !account && !saves_dir.empty() && link->me()) // The game's save folder for this account.
      account = std::make_unique<WinFs>(saves_dir + L"\\" + std::to_wstring(link->me()), backups_dir);
    std::string request = take_text(folder + L"coop-request.txt", DWORD(coop::kMaxRequestFile));
    // Taken at every pass, even when it cannot go, so a typed line never stays on disk. Never logged.
    const std::string typed = take_text(folder + L"coop-say.txt");
    // Night Operation's line (nightop/run.lua), taken at every pass too: the newest state goes, an old one never waits.
    std::string night = take_text(folder + L"coop-night.txt");
    while (!night.empty() && (night.back() == '\n' || night.back() == '\r'))
      night.pop_back();
    const std::string raced = take_text(folder + L"coop-race.txt", kRaceFile); // Never logged either.
    coop::Command command = coop::parse_request(request).command;
    if (switched_off && !request.empty() && command != coop::Command::report) {
      event("coop off is active until the game restarts: request ignored");
      request.clear();
    }
    switch (request.empty() ? coop::Command::none : command) { // The pose path's requests never reach the link.
    case coop::Command::loopback: {
      coop::Request r = coop::parse_request(request);
      event(coop::pose::ask_loopback(!r.off, static_cast<uint32_t>(r.ms), static_cast<uint32_t>(r.jitter),
                                     static_cast<uint32_t>(r.loss)));
      request.clear();
      break;
    }
    case coop::Command::record:
      event(coop::pose::ask_record(!coop::parse_request(request).off));
      request.clear();
      break;
    case coop::Command::replay:
      event(coop::pose::ask_replay(!coop::parse_request(request).off));
      request.clear();
      break;
    case coop::Command::nightop:
      event(coop::pose::ask_nightop(coop::parse_request(request).rule, GetTickCount64()));
      request.clear();
      break;
    case coop::Command::fight:
      event(coop::pose::ask_fight(coop::parse_request(request), coop_marker));
      request.clear();
      break;
    case coop::Command::quests:
      event(coop::pose::ask_quests(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::travel: // The follow's call: the game thread's.
      event(coop::pose::ask_travel(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::items: // coop gift's inventory read: the worker's, now.
      event(coop::pose::ask_items(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::rows: // The rows of coop lion, coop gardener/tendril fight, the Shock Bolt, coop mxiii, the
                              // shop: the game thread's.
      event(coop::pose::ask_rows(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::freeze: {
      coop::Request r = coop::parse_request(request);
      event(coop::pose::ask_freeze(!r.off, r.ms, GetTickCount64()));
      request.clear();
      break;
    }
    case coop::Command::gate: // coop fly and coop slowmo: the game thread's.
      event(coop::pose::ask_gate(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::anim: // coop emote's native clips: the game thread's too.
      event(coop::pose::ask_anim(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::shortcut: // coop shortcut's list, or a load's read: the game thread's reads.
      if (const coop::Request ask = coop::parse_request(request); ask.slot < 0) {
        event(coop::pose::ask_shortcut());
      } else { // Checked now and again before the write, which the read's end starts (below).
        GameView game;
        const std::string why = coop_saves.plant_refusal(account.get(), game);
        event(why.empty() ? coop::pose::ask_shortcut_load(ask.slot) : "shortcut load refused: " + why);
      }
      request.clear();
      break;
    case coop::Command::devinfo: // coop devinfo: the game thread's too.
      event(coop::pose::ask_devinfo(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::nightshop: // The Night Operation shop's screen: the game thread's.
      event(coop::pose::ask_nightshop(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::roxanne: // Roxanne's Night Operation choices: the game thread's.
      event(coop::pose::ask_roxanne(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::saves:
      if (const coop::Request ask = coop::parse_request(request); ask.saves == coop::SavesAsk::probe) {
        event(coop::pose::saves_probe());
        if (account) // The plan, from stats and the manifest only.
          event(coop::twins::describe(coop::twins::plan(*account)));
      } else {
        GameView game;
        event(coop_saves.ask(ask.saves, account.get(), game, ask.slot));
      }
      request.clear();
      break;
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
    if (!probed) { // Once, at the first pass after the pin: how far the game got when the DLL loaded (H0).
      probed = true;
      event(coop::pose::saves_probe());
    }
    // After worker_poll, which pins the build. Two reads and six, so every 250 ms, not at every 5 ms pass.
    if (uint64_t now = GetTickCount64(); now >= next_slot) {
      next_slot = now + 250;
      slot_index = coop::pose::loaded_slot();
      const coop::slot::Saves was = saves_state;
      saves_state = coop::pose::saves();
      if (saves_state != was) { // Each change once, with why it reads off or ? (an entry that moved latches it: H6).
        const std::string why = coop::pose::saves_why();
        event(std::string("save name: saves=") + coop::slot::saves_name(saves_state) +
              (why.empty() ? std::string() : " (" + why + ")"));
      }
    }
    { // A conversion's next job, at most one a pass, then the switch asked at its end.
      GameView game;
      for (const std::string &line : coop_saves.pass(account.get(), game, switched_off))
        event(line);
    }
    for (const std::string &line : coop::pose::shortcut_pass()) // coop shortcut's lines, as the game thread reads.
      event(line);
    if (std::string save, line; coop::pose::shortcut_load_pass(save, line)) { // A load's file read and cleaned.
      event(line);
      if (!save.empty()) {
        GameView game;
        const std::string what = line.substr(0, line.find(" cleaned:")); // "shortcut F02 1", cleaned_line's start.
        event(coop_saves.plant(account.get(), game, coop::shortcut::kSlot, std::move(save), what));
      }
    }
    streaming = coop::pose::worker_stream();
    watch_saves(GetTickCount64(), loaded ? link->me() : 0);
    if (loaded) { // Before ready(): a +connect_lobby there is held until a world loads.
      link->world(coop::pose::lua_state().world);
      // Ours as Lua last wrote it; photo_sync=both is sent as notice while this game cannot pause. cut: the guest's Lua
      // asks for the pause during the host's cutscene.
      const coop::State lua = coop::pose::lua_state();
      link->photo(lua.photo,
                  lua.sync == coop::Sync::both && !coop::pose::can_freeze() ? coop::Sync::notice : lua.sync, lua.max,
                  lua.cut);
      link->mod_names(lua.names);
      link->pose_rate(lua.rate);
      link->loopback(coop::pose::loopback());
    }
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
        if (const std::string code = link->take_copy(); !code.empty()) {
          const bool copied = coop::copy_text(std::wstring(code.begin(), code.end()));
          event(copied ? "join code copied to the clipboard" : "join code not copied: the clipboard refused it");
          link->notice(copied ? "Join code " + code + " copied." : "Could not copy the join code " + code + ".");
        }
        // Chat and vitals (UI-DESIGN 5): a session's end deletes both files (a fail line from before its start still
        // reaches Lua); Lua's line goes; ours are read every 100 ms; her lines (or our failures) go to Lua once it took
        // the last file.
        const bool chatting = !switched_off && link->chatting();
        if (chat_was && !chatting)
          delete_chat();
        chat_was = chatting;
        if (!switched_off) {
          if (!typed.empty())
            link->say(typed);
          if (!night.empty() && link->linked())
            link->night(night); // Lua logs its lines; the link logs a refusal past the rate.
          // Each whole line, in order; a line cut by kRaceFile is no line.
          for (size_t at = 0, end; (end = raced.find('\n', at)) != std::string::npos; at = end + 1)
            if (end > at)
              link->race(raced.substr(at, end - at));
          coop::Vitals mine;
          if (const uint64_t now = GetTickCount64(); chatting && now >= next_vitals) {
            uint64_t took_us = 0;
            if (coop::pose::local_vitals(mine, took_us))
              link->vitals(mine);
            next_vitals = now + (took_us > 1000 ? 500 : 100); // 10 Hz; 2 Hz after a read over 1 ms (UI-DESIGN 7.3).
          }
          const std::wstring chat = folder + L"coop-chat.txt";
          if (link->chat_waiting() && GetFileAttributesW(chat.c_str()) == INVALID_FILE_ATTRIBUTES) {
            std::string text;
            for (const std::string &line : link->take_chat())
              text += line + "\n";
            if (!write_text(chat, text))
              DeleteFileW((chat + L".tmp").c_str()); // A line lost, never one left on disk.
          }
        }
        api.release_memory(); // Valve's advice for threads other than the game's.
      }
    }
    bool linked = loaded && ready != coop::Link::Ready::no && !switched_off && link->linked();
    // The friend's photo mode holds our pause while the link says so and a save is loaded (the title screen has nothing
    // to pause); a fault's line goes on screen.
    std::string said = coop::pose::freeze_pass(
        loaded && !switched_off && link->photo_freeze() && coop::pose::lua_state().world, GetTickCount64());
    if (loaded && !said.empty())
      link->notice(said);
    said = coop::pose::debug_pass(linked, coop_marker, GetTickCount64());
    if (loaded && !said.empty())
      link->notice(said);
    said = coop::pose::anim_pass();
    if (loaded && !said.empty())
      link->notice(said);
    // Channel 2 both ways: the shared quests take their SBQ lines out first, the shared fight's job gets the rest; the
    // lobby owner hosts both. Ours are queued for the next tick.
    std::vector<std::string> channel2 = loaded ? link->take_fight() : std::vector<std::string>();
    coop::pose::quest_pass(
        GetTickCount64(), linked && link->host(), linked ? link->partner() : 0, coop_marker, channel2,
        [](const std::string &line) { return link && link->send_fight(line, true); }, quest_files);
    bool fighting = coop::pose::fight_pass(
        GetTickCount64(), linked, linked && link->host(), coop_marker, channel2,
        [](const std::string &line, bool reliable) { return link && link->send_fight(line, reliable); },
        linked ? link->mate_life() : coop::Life::unknown);
    streaming = streaming || fighting;
    // Every send passes here, worker_poll's and worker_stream's before this pass's ready(): none once Steam shut down.
    coop::pose::peer(
        linked, GetTickCount64(),
        [](const uint8_t *d, size_t n, bool reliable) {
          if (api.user_handle())
            link->send_binary(d, n, reliable);
        },
        linked ? link->pose_cap() : coop::kPoseCaps[0]);
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
  MoveFileExW((folder + L"nightop-probe.txt").c_str(), (folder + L"nightop-probe.old.txt").c_str(),
              MOVEFILE_REPLACE_EXISTING); // A relaunch before the files were sent keeps the last T6 probe.
  MoveFileExW((folder + L"coop-fight.log").c_str(), (folder + L"coop-fight.old.log").c_str(),
              MOVEFILE_REPLACE_EXISTING);
  MoveFileExW((folder + L"coop-quests.log").c_str(), (folder + L"coop-quests.old.log").c_str(),
              MOVEFILE_REPLACE_EXISTING);
  DeleteFileW((folder + L"coop-request.txt").c_str()); // A request or report left from a previous run is stale.
  delete_chat();                                       // And chat lines nobody took.
  DeleteFileW((folder + L"coop-report.txt").c_str());
  // And a previous run's world state, whose world=1 would release a held invite on the title screen.
  for (const wchar_t *stale : {L"coop-components.txt", L"coop-remote.txt", L"coop-display.txt", L"coop-state.txt",
                               L"coop-night.txt", L"coop-cns.txt"})
    DeleteFileW((folder + stale).c_str()); // Tables, addresses and a run's line from a previous run mean nothing now.
  write_header();
  log_paks();
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
      delete_chat(); // A typed line nobody will take now.
      return 0;      // Steam may be gone or a lock held: never call it again.
    }
    Sleep(streaming ? 5 : 50);
  }
  coop::pose::block();
  append(utc_stamp() + " worker stopped: Steam exports missing");
  return 0;
}
} // namespace

extern "C" BOOL WINAPI DllMain(HINSTANCE self, DWORD reason, LPVOID reserved) {
  if (reason == DLL_PROCESS_DETACH && reserved) {
    // The process is exiting (other threads are already gone): one last line, stack only, no heap, no Steam.
    if (log_open) {
      SYSTEMTIME t;
      GetSystemTime(&t);
      char text[96];
      int n = wsprintfA(text, "%04u-%02u-%02uT%02u:%02u:%02u.%03uZ worker stopped: process exit%s\r\n", t.wYear,
                        t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond, t.wMilliseconds,
                        faulted ? " (after a fault)" : "");
      append_raw(text, static_cast<DWORD>(n));
    }
    delete_chat(); // Stack only: the paths were kept at attach (empty when it stayed idle, which deletes nothing).
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
  if (log.size() + 4 >= MAX_PATH)
    return TRUE; // A path this long would not be loggable, nor coop-chat.txt.tmp deletable; stay idle.
  lstrcpyW(log_path, log.c_str());
  const wchar_t *const chat_names[6] = {L"coop-say.txt",      L"coop-say.txt.tmp", L"coop-chat.txt",
                                        L"coop-chat.txt.tmp", L"coop-race.txt",    L"coop-race.txt.tmp"};
  for (int i = 0; i < 6; ++i)
    lstrcpynW(chat_files[i], (folder + chat_names[i]).c_str(), MAX_PATH);
  if (HANDLE thread = CreateThread(nullptr, 0, worker, nullptr, 0, nullptr))
    CloseHandle(thread);
  return TRUE;
}
