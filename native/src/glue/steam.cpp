// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
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
// Night Operation's line from Lua's coop-night.txt to the link (hers comes back in the status), our parked bike's line
// from Lua's coop-parked.txt to the link (the members' come back in the status), the race lines Lua writes into
// coop-race.txt and coop gift's lines from Lua's gift requests (hers of both reach Lua through coop-chat.txt). It
// makes the co-op save copies at the title and switches the game's save name to them on request (game/twins.h), and
// puts our join code on the clipboard on the copy request (glue/clipboard.h). The follow's camps lines go through the
// link (link/core.h), its travel request to the game thread (glue/tick.cpp).
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX // std::min in game/table.h.
#include <windows.h>

#include <algorithm>
#include <atomic>
#include <cstdint>
#include <map>
#include <memory>
#include <string>
#include <vector>

#include "link/pak_list.h"
#include "closet/packs.h" // pack_list: coop-cns-packs.txt
#include "glue/clipboard.h"
#include "glue/tick.h"
#include "link/core.h"
#include "game/events.h" // NameBook, send_from, SlotWatch: our asset names to every member
#include "game/keep.h"  // kFileBytes
#include "game/table.h" // path_allowed
#include "game/rotation.h"      // rotation_name(), stamped()
#include "game/shortcut_load.h" // kSlot
#include "game/slot.h"
#include "game/twins.h"
#include "online/saves/watch.h"

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
// Callback 506's last event, for the log only (a member's leave still shows in the next poll of the members).
std::atomic<uint64_t> chat_lobby{0}, chat_user{0};
std::atomic<uint32_t> chat_state{0};
std::atomic<int> cb506{0};

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
Listener on_chat(
    coop::kChatUpdateId,
    [](const void *p) {
      const auto *u = static_cast<const coop::ChatUpdate *>(p);
      chat_lobby.store(u->lobby);
      chat_state.store(u->state);
      chat_user.store(u->user); // Last: the worker takes the event by it.
      ++cb506;
    },
    sizeof(coop::ChatUpdate));
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
// complete. 512 by default: a chat line, a night line (link/protocol.h's kMaxNight) or a bike line (about 200 bytes)
// with its line end; a request takes link/protocol.h's kMaxRequestFile.
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
// Each line with its SteamIDs and join codes masked (link/protocol.h's masked): bug reports bring this log too.
void append(const std::string &line) {
  if (log_capped)
    return;
  std::string text = coop::masked(line) + "\r\n";
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
bool sbo_title_held = false; // C1 holds a co-op slot (pose::sbo_title_pass): the conversion's pass waits.
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

// The .pak mods the game loads beyond the base game's (link/pak_list.h), from SB\Content\Paks next to the exe's
// SB\Binaries\Win64 and its folders 8 levels down (4096 files at most; the engine mounts paks at any depth), read once
// at start: a header line names them, and each friend gets their count and hash, and our mod containers by name. The
// CNS packs among the files (.dekcns.json under ~mods, kMaxCnsPacks read, kMaxCnsBytes each) are counted with their
// outfits for the log and the status's cns= line, and the assets they declare (cns_assets) go to coop-cns.txt, a
// "<path> <outfit>" line each, sorted, written at every start (empty without CNS packs): the only paths of a mod
// online/partner/puppet.lua loads when a friend's table names one, and the outfits online/partner/capture.lua tags her
// parts with. The pack files themselves go to coop-cns-packs.txt ("<size> <time> <path>" lines, closet/packs.h's
// pack_list), also at every start, for closet/packs.lua, which reads and parses them. A pack whose path Lua cannot open
// (a byte outside ASCII) is copied beside the list first, its line naming the copy.
// The .uasset paths each mod container's .utoc indexes (utoc_assets, kMaxUtocBytes read of each), by container name,
// kMaxModAssets in all, each path one game/table.h's path_allowed takes: what coop-shared-assets.txt lists of the
// containers a friend has in the same version.
coop::Paks game_paks;
std::vector<coop::PakMod> game_mods;
std::map<std::string, std::vector<std::string>> game_mod_assets;
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
  std::vector<coop::closet::PackFile> pack_files; // Every file, for the closet's pack list.
  size_t packs = 0;
  uint64_t outfits = 0;
  std::map<std::string, std::string> assets;
  for (auto &f : files) {
    paks.push_back({f.name, f.size});
    pack_files.push_back({f.name, f.size, f.mtime});
    if (packs < coop::kMaxCnsPacks && coop::cns_pack(f.name)) {
      bool exists = false;
      ++packs;
      const std::string json =
          coop::pose::read_file(dir + L"\\Content\\Paks\\" + wide(f.name), exists, coop::kMaxCnsBytes);
      outfits += coop::cns_outfits(json);
      coop::cns_assets(json, assets);
    }
  }
  size_t mod_assets = 0;
  for (auto &f : files) {
    const std::string path = coop::paks_detail::lower(f.name);
    if (!coop::paks_detail::ends(path, ".utoc") || coop::base_pak(path) || mod_assets >= coop::kMaxModAssets)
      continue;
    bool exists = false;
    const std::string toc =
        coop::pose::read_file(dir + L"\\Content\\Paks\\" + wide(f.name), exists, coop::kMaxUtocBytes);
    std::vector<std::string> found;
    coop::utoc_assets(toc, found, coop::kMaxModAssets - mod_assets);
    auto &kept = game_mod_assets[coop::mod_name(path.substr(0, path.rfind('.')))];
    for (std::string &asset : found)
      if (coop::pose::path_allowed(asset))
        kept.push_back(std::move(asset)), ++mod_assets;
  }
  std::string declared;
  for (const auto &[path, fit] : assets)
    declared += path + " " + fit + "\n";
  write_text(folder + L"coop-cns.txt", declared);
  // The closet's pack list, after the copies it names. A copy reads one byte past kMaxCnsBytes, so Lua still finds a
  // longer pack too long. A pack gone since the listing leaves no copy. Copies a previous start left past these go:
  // they are numbered from 1, so the first one missing ends them.
  const coop::closet::PackList listed = coop::closet::pack_list(std::move(pack_files));
  for (const auto &[path, copy] : listed.copies) {
    bool exists = false;
    const std::string json =
        coop::pose::read_file(dir + L"\\Content\\Paks\\" + wide(path), exists, coop::kMaxCnsBytes + 1);
    if (!exists || !write_text(folder + wide(copy), json))
      DeleteFileW((folder + wide(copy)).c_str());
  }
  for (size_t stale = listed.copies.size() + 1;
       DeleteFileW((folder + wide(coop::closet::copy_name(stale))).c_str()) && stale < coop::kMaxCnsPacks; ++stale)
    continue;
  write_text(folder + L"coop-cns-packs.txt", listed.text); // For closet/packs.lua.
  game_paks = coop::digest(paks);
  game_mods = coop::mods(paks);
  std::string names = game_paks.names.size() > 1000 ? game_paks.names.substr(0, 1000) + "..." : game_paks.names;
  header_lines.push_back("paks " + std::to_string(game_paks.count) + " beyond the base game, hash " +
                         std::to_string(game_paks.hash) + (names.empty() ? "" : ": " + names));
  append(utc_stamp() + " " + header_lines.back());
  if (mod_assets) {
    header_lines.push_back("mod assets " + std::to_string(mod_assets) + " indexed in " +
                           std::to_string(game_mod_assets.size()) + " .utoc files");
    append(utc_stamp() + " " + header_lines.back());
  }
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

// The co-op saves' file functions (game/twins.h): names in this account's save folder, and in a new folder of the
// backups' folder. Reads share everything, so the game's own writes are never blocked; writes are flushed before
// their rename. The SBO lobby's (glue/tick.h's SboFs) add each co-op slot's rotation folder,
// StellarCoopBackups\autosave\StellarBladeCoop0N\, and its sidecar backups' folder,
// StellarCoopBackups\sidecar\StellarCoopSBO0N\, each made when first used.
class WinFs final : public coop::pose::SboFs {
public:
  WinFs(const std::wstring &dir, const std::wstring &backups) : dir_(dir + L"\\"), backups_(backups) {}
  coop::twins::Stat stat(const std::string &name) override {
    WIN32_FILE_ATTRIBUTE_DATA a;
    if (!GetFileAttributesExW((dir_ + wide(name)).c_str(), GetFileExInfoStandard, &a) ||
        (a.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY))
      return {};
    return {true, (uint64_t(a.nFileSizeHigh) << 32) | a.nFileSizeLow,
            (uint64_t(a.ftLastWriteTime.dwHighDateTime) << 32) | a.ftLastWriteTime.dwLowDateTime};
  }
  bool read(const std::string &name, std::string &out, size_t max) override {
    return read_at(dir_ + wide(name), out, max);
  }
  bool write(const std::string &name, const std::string &bytes) override { return write_at(dir_ + wide(name), bytes); }
  bool rename(const std::string &from, const std::string &to) override {
    return MoveFileExW((dir_ + wide(from)).c_str(), (dir_ + wide(to)).c_str(),
                       MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH);
  }
  bool remove(const std::string &name) override { return DeleteFileW((dir_ + wide(name)).c_str()); }
  std::vector<std::string> list() { return list_at(dir_); }
  std::wstring folder() const override { return dir_; }
  bool rotation_write(int slot, const std::string &name, const std::string &bytes) override {
    const std::wstring dir = rotation_dir(slot);
    return !dir.empty() && coop::rotation::rotation_name(name) && store(dir + wide(name), bytes);
  }
  bool rotation_read(int slot, const std::string &name, std::string &out, size_t max) override {
    const std::wstring dir = rotation_dir(slot);
    return !dir.empty() && coop::rotation::rotation_name(name) && read_at(dir + wide(name), out, max);
  }
  std::vector<std::string> rotation_list(int slot) override {
    const std::wstring dir = rotation_dir(slot);
    return dir.empty() ? std::vector<std::string>() : list_at(dir);
  }
  bool rotation_remove(int slot, const std::string &name) override {
    const std::wstring dir = rotation_dir(slot);
    return !dir.empty() && coop::rotation::rotation_name(name) && DeleteFileW((dir + wide(name)).c_str());
  }
  // name: <UTC>.bin, or <UTC>-1.bin, -2... when it is there already, as backup_dir names its folders.
  bool sidecar_backup(int slot, const std::string &name, const std::string &bytes) override {
    const std::wstring dir = slot_dir(L"sidecar", coop::twins::sidecar_name(slot), slot);
    if (dir.empty() || !coop::rotation::stamped(name, ".bin") || name.size() != 20)
      return false;
    for (int n = 0; n < 100; ++n) {
      const std::wstring path = dir + wide(n ? name.substr(0, 16) + "-" + std::to_string(n) + ".bin" : name);
      if (store(path, bytes))
        return true;
      if (GetFileAttributesW(path.c_str()) == INVALID_FILE_ATTRIBUTES)
        return false;
    }
    return false;
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
  bool backup_write(const std::string &name, const std::string &bytes) {
    return !current_.empty() && store(current_ + wide(name), bytes);
  }
  bool backup_read(const std::string &name, std::string &out, size_t max) {
    return !current_.empty() && read_at(current_ + wide(name), out, max);
  }

private:
  // Written beside as .coop-tmp, then renamed: a full disk or a killed game never leaves a cut file in a backup. A file
  // already at path stays, and the store fails.
  static bool store(const std::wstring &path, const std::string &bytes) {
    const std::wstring temp = path + L".coop-tmp";
    if (write_at(temp, bytes) && MoveFileExW(temp.c_str(), path.c_str(), MOVEFILE_WRITE_THROUGH))
      return true;
    DeleteFileW(temp.c_str());
    return false;
  }
  static std::vector<std::string> list_at(const std::wstring &dir) {
    std::vector<std::string> names;
    WIN32_FIND_DATAW f;
    HANDLE h = FindFirstFileW((dir + L"*").c_str(), &f);
    if (h == INVALID_HANDLE_VALUE)
      return names;
    do {
      if (!(f.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY))
        names.push_back(utf8(f.cFileName));
    } while (FindNextFileW(h, &f));
    FindClose(h);
    return names;
  }
  // StellarCoopBackups\<kind>\<name without its extension>\ for co-op slot slot, made when missing; empty when the
  // backups' folder is unknown or there is no such slot.
  std::wstring slot_dir(const wchar_t *kind, const std::string &name, int slot) {
    if (backups_.empty() || slot < 0 || slot >= coop::twins::kSlots)
      return {};
    std::wstring path = backups_;
    CreateDirectoryW(path.c_str(), nullptr); // Each already there after its first use.
    for (const std::wstring &part : {std::wstring(kind), wide(name.substr(0, name.rfind('.')))}) {
      path += L"\\" + part;
      CreateDirectoryW(path.c_str(), nullptr);
    }
    return path + L"\\";
  }
  std::wstring rotation_dir(int slot) { return slot_dir(L"autosave", coop::twins::twin_name(slot), slot); }

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
uint64_t was_pair = 0;    // Link::partner() at the last pass.
// Our asset names (game/events.h's SBA lines): every line of this link session, each member's cursor in it and byte
// budget, when the budgets were last refilled, linked() at the last pass and each ghost slot's member.
struct NamesSent {
  size_t cursor = 0, budget = coop::pose::kNamesBytesPerSecond;
};
coop::pose::NameBook names_book;
std::map<uint64_t, NamesSent> names_sent;
uint64_t names_at = 0;
bool names_linked = false;
coop::pose::SlotWatch names_slots;
// Link::solo_pair() at the last pass: story together and the shared fight send nothing to the pair while it holds.
bool pair_paused = false;
uint64_t next_vitals = 0; // Our vitals are read every 100 ms in a chat session (500 after a read over 1 ms).
bool switched_off = false; // coop off: until the game restarts, only coop status and coop report get an answer.
std::wstring command_line;
bool loaded = false, streaming = false; // streaming: the loopback, a recording, a replay or a friend: a pass each 5 ms.
std::string written;

// The co-op saves (game/twins.h): this account's file functions once the SteamID is known, and the requests and
// passes, against the game as glue/tick.cpp reads it.
std::unique_ptr<WinFs> account;
coop::twins::Switch coop_saves;
// The shared quests' record beside co-op slot n (StellarCoopQuests0N.txt), through game/twins.h's name check and put.
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
  int reloading() { return coop::pose::reloading(); }
  std::string swap(bool coop) {
    std::string why = coop::pose::saves_switch(coop);
    saves_state = coop::pose::saves(); // The status shows the switch at once.
    return why;
  }
};

// coop-shared-assets.txt (link/pak_list.h's shared_assets): rewritten when her containers of our version change, its
// version bumped, which the status's shared= line gives Lua: "shared=<version> <paths>".
std::vector<std::string> shared_mods;
uint64_t shared_version = 0;
size_t shared_count = 0;
void write_shared() {
  std::vector<std::string> same = link && loaded ? link->same_mods() : std::vector<std::string>();
  if (same == shared_mods && shared_version)
    return;
  const std::string text = coop::shared_assets(game_mod_assets, same);
  if (!write_text(folder + L"coop-shared-assets.txt", text))
    return; // Tried again next pass: shared_mods is kept until the file holds the new list.
  shared_mods = std::move(same);
  shared_count = size_t(std::count(text.begin(), text.end(), '\n'));
  ++shared_version;
}

std::string status_text() {
  std::string head = link ? link->status(coop::Counters{cb333.load(), cb505.load(), cb506.load(), cb1251.load()})
                          : "mod=" + coop::token(STELLARCOOP_VERSION) + " proto=" +
                                std::to_string(coop::kProtocol) + " steam=waiting\n";
  const std::string camps = coop::pose::camps_status();
  const std::string camp_text = coop::pose::camp_text_status();
  const std::string uidev = coop::pose::uidev_status();
  return head + cns_line + "shared=" + std::to_string(shared_version) + " " + std::to_string(shared_count) + "\n" +
         coop::pose::status() + "\n" + coop::pose::sky_status() + (camps.empty() ? camps : camps + "\n") +
         coop::slot::line(slot_index, coop_marker, coop::pose::lua_state().world, saves_state) + "\n" +
         coop_saves.status() + "\n" + coop::pose::fight_status() + "\n" + coop::pose::pilot_status() + "\n" +
         coop::pose::sbo_status() + "\n" + (uidev.empty() ? uidev : uidev + "\n") + coop::pose::rows_status() + "\n" +
         (camp_text.empty() ? camp_text : camp_text + "\n") +
         coop::pose::quest_status() + coop::pose::world_status() + "\n" + coop::pose::story_status() + "\n" +
         (link ? link->photo_status(coop::pose::frozen()) + "\n" : std::string()) +
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
  // Masked like coop-link.log: the status and the save folder's names carry SteamIDs and our join code.
  event(write_text(folder + L"coop-report.txt", coop::masked(text)) ? "report written to coop-report.txt"
                                                                     : "report not written");
}

// Asset names, before this pass files the members' SBA lines: a link session that starts or ends empties our book and
// cursors. Our keys then start again from 1 (asset_keys_clear()). A ghost slot whose member changed forgets her names
// (asset_slot_reset()) before her lines of this pass are filed, so the first ones stay.
void names_watch(bool linked) {
  if (linked != names_linked) {
    names_linked = linked;
    names_book.clear();
    names_sent.clear();
    coop::pose::asset_keys_clear();
  }
  uint64_t ids[coop::kMaxRemote] = {};
  if (linked)
    for (const auto &p : link->peers())
      if (p.compatible && p.accepted && p.slot < coop::kMaxRemote)
        ids[p.slot] = p.id;
  names_slots.pass(ids, coop::kMaxRemote, linked, [](size_t slot) { coop::pose::asset_slot_reset(slot); });
}
// Our asset names, after the fight pass. Each member past the handshake gets the book from her cursor, at
// kNamesBytesPerSecond, while fewer than kFightQueue / 4 channel-2 lines wait for her: the pair's fight, world and
// story lines and the poses keep their room. A member who came in later gets every earlier line. A member gone loses
// her cursor.
void names_pass(bool linked) {
  for (std::string &line : coop::pose::asset_lines(linked)) // Also while not linked: the loopback's slot 0 takes them.
    if (linked)
      names_book.add(std::move(line));
  const uint64_t now = GetTickCount64(), refill = (now - names_at) * coop::pose::kNamesBytesPerSecond / 1000;
  names_at = now;
  if (!linked)
    return;
  const std::vector<uint64_t> members = link->members();
  for (auto it = names_sent.begin(); it != names_sent.end();)
    it = std::find(members.begin(), members.end(), it->first) == members.end() ? names_sent.erase(it) : std::next(it);
  for (const uint64_t id : members) {
    auto [it, fresh] = names_sent.try_emplace(id);
    NamesSent &n = it->second;
    if (!fresh)
      n.budget = static_cast<size_t>(std::min<uint64_t>(coop::pose::kNamesBytesPerSecond, n.budget + refill));
    coop::pose::send_from(names_book, n.cursor, n.budget, [id](const std::string &line) {
      return link->queued_for(id) < coop::kFightQueue / 4 && link->send_fight(line, true, id);
    });
  }
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
      link = std::make_unique<coop::Link>(
          api, STELLARCOOP_VERSION, event,
          [](size_t slot, const uint8_t *d, size_t n) { coop::pose::peer_receive(slot, d, n); });
      link->paks(game_paks.count, game_paks.hash, game_mods);
      bool exists = false; // The block list, kept across game runs; no file yet is an empty list.
      const std::wstring blocked = folder + L"coop-blocked.txt";
      const std::string text = coop::pose::read_file(blocked, exists, coop::kMaxBlockFile);
      // read_file() cannot tell a missing file from one it could not open, nor a read cut short: the size can.
      WIN32_FILE_ATTRIBUTE_DATA file{};
      const bool there = GetFileAttributesExW(blocked.c_str(), GetFileExInfoStandard, &file);
      link->blocks(text, !there || (!file.nFileSizeHigh && file.nFileSizeLow == text.size()));
    }
    if (loaded && !account && !saves_dir.empty() && link->me()) { // The game's save folder for this account.
      account = std::make_unique<WinFs>(saves_dir + L"\\" + std::to_wstring(link->me()), backups_dir);
      coop::pose::sbo_files(account.get());
    }
    std::string request = take_text(folder + L"coop-request.txt", DWORD(coop::kMaxRequestFile));
    // Taken at every pass, even when it cannot go, so a typed line never stays on disk. Never logged.
    const std::string typed = take_text(folder + L"coop-say.txt");
    // Night Operation's line (online/modes/nightop/run.lua), taken at every pass too: the newest state goes, an old one
    // never waits.
    std::string night = take_text(folder + L"coop-night.txt");
    while (!night.empty() && (night.back() == '\n' || night.back() == '\r'))
      night.pop_back();
    // Our parked bike's line (vehicles/bike/ride.lua), taken the same way: the newest state wins.
    std::string parked = take_text(folder + L"coop-parked.txt");
    while (!parked.empty() && (parked.back() == '\n' || parked.back() == '\r'))
      parked.pop_back();
    // The keep's list (core/keep.lua writes the whole list each time it grows), taken at every pass the same way.
    if (const std::string kept = take_text(folder + L"coop-keep.txt", DWORD(coop::keep::kFileBytes)); !kept.empty())
      if (const std::string said = coop::pose::keep_take(kept); !said.empty())
        event(said);
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
    case coop::Command::world: // The shared world's setting and status line.
      event(coop::pose::ask_world(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::scenes: // Story together's setting and status line.
      event(coop::pose::ask_scenes(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::spectate: // Spectate's setting, status and test: the game thread's step reads them.
      event(coop::pose::ask_spectate(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::travel: // The follow's call: the game thread's.
      event(coop::pose::ask_travel(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::items: // coop gift's inventory read: the worker's, now; logged as an alias's answer changes.
      if (const std::string said = coop::pose::ask_items(coop::parse_request(request)); !said.empty())
        event(said);
      request.clear();
      break;
    case coop::Command::fishbook: // The fishing tournament's book read: the worker's, now; logged as its kind changes.
      if (const std::string said = coop::pose::ask_fishbook(coop::parse_request(request)); !said.empty())
        event(said);
      request.clear();
      break;
    case coop::Command::photohunt: // The photo hunt's photo check: the game thread's; the worker logs each ask.
      event(coop::pose::ask_photohunt(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::rows: // The rows of coop lion, coop gardener/tendril fight, the Shock Bolt, coop mxiii's four, the
                              // shop, Lily's signal: the game thread's.
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
    case coop::Command::bike: // The bike's preload and SB's actions while she rides: the game thread's too.
      event(coop::pose::ask_bike(coop::parse_request(request)));
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
    case coop::Command::race: // Doro races' hold on EVE: the game thread's too.
      event(coop::pose::ask_race(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::hud: // SB's HUD under the SBO lobby's screens: the game thread's; the change is logged.
      coop::pose::ask_hud(coop::parse_request(request).on);
      request.clear();
      break;
    case coop::Command::pausetab: // The pause menu's Online tab: the game thread's hook reads it; a change is logged.
      coop::pose::ask_pause_tab(coop::parse_request(request).on);
      request.clear();
      break;
    case coop::Command::popups: // The game's popups during online play: the game thread's pass reads it; logged.
      coop::pose::ask_popups(coop::parse_request(request).on);
      request.clear();
      break;
    case coop::Command::closet: // The closet's pad chord: the game thread's pad step reads it; logged.
      coop::pose::ask_pad_closet(coop::parse_request(request).on);
      request.clear();
      break;
    case coop::Command::sky: // The day/night cycle: the game thread's; each change of state is logged.
      coop::pose::ask_sky(coop::parse_request(request));
      request.clear();
      break;
    case coop::Command::loading: // The SBO lobby arrival's black lifted: the game thread's; its answer is logged.
      event(coop::pose::ask_loading());
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
    case coop::Command::teamshop: // The team shop's screen: the game thread's.
      event(coop::pose::ask_teamshop());
      request.clear();
      break;
    case coop::Command::sboxion: // SBO Xion's warp and its way out: the game thread's.
      event(coop::pose::ask_sboxion(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::roxanne: // Roxanne's Night Operation choices or Lily's signal choice: the game thread's.
      event(coop::pose::ask_roxanne(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::guardtext: // The Xion guard's lines: the game thread's.
      event(coop::pose::ask_guard(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::signal: // The mod's own quests, their reads, acquires or a task's Complete: the game thread's.
      event(coop::pose::ask_signal(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::sbo: // The SBO lobby: the worker's, the Join slot's swap included.
      event(coop::pose::ask_sbo(coop::parse_request(request)));
      request.clear();
      break;
    case coop::Command::saves:
      if (const coop::Request ask = coop::parse_request(request); ask.saves == coop::SavesAsk::probe) {
        event(coop::pose::saves_probe());
        if (account) // The plan, from stats and the manifest only.
          event(coop::twins::describe(coop::twins::plan(*account)));
      } else {
        GameView game;
        event(coop_saves.ask(ask.saves, account.get(), game, ask.slot, ask.target));
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
      // C1, the SBO session records left open: at each title pass, before any conversion job, and after coop off too,
      // so its two reads of the client ignore coop off (Lua still writes world= then).
      GameView game;
      sbo_title_held = coop::pose::sbo_title_pass(
          coop::slot::not_title(game.world(), game.title(), coop::pose::load_mode(true), coop::pose::reloading(true))
              .empty());
    }
    if (!sbo_title_held) { // A conversion's next job, at most one a pass, then the switch asked at its end.
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
    const uint32_t ours = coop::pose::zone_type(); // Our zone's type, once a pass: the vitals and the solo pause.
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
        // may be dispatching. Four inserts, once per run; never register or unregister anywhere else.
        api.register_callback(&on_join, coop::kJoinRequestedId);
        api.register_callback(&on_data, coop::kDataUpdateId);
        api.register_callback(&on_chat, coop::kChatUpdateId);
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
        if (uint64_t user = chat_user.exchange(0))
          link->member_update({chat_lobby.load(), user, 0, chat_state.load()});
        link->tick(GetTickCount64(), request, join, session);
        if (link->take_report())
          write_report();
        if (const std::string blocks = link->take_blocks(); !blocks.empty()) {
          const bool saved = write_text(folder + L"coop-blocked.txt", blocks);
          event(saved ? "block list saved to coop-blocked.txt" : "block list not saved");
          if (!saved)
            link->notice("Could not save the block list: it holds until the game closes.");
        }
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
          if (!parked.empty())
            link->bike(parked); // Linked or not: send_bike() hands it to each member once there is one.
          // Each whole line, in order; a line cut by kRaceFile is no line.
          for (size_t at = 0, end; (end = raced.find('\n', at)) != std::string::npos; at = end + 1)
            if (end > at)
              link->race(raced.substr(at, end - at));
          // Our New Game+ count and difficulty, each pass once read, so ours is known before a link (the cycle line).
          if (uint32_t count = 0, difficulty = 0; coop::pose::local_cycle(count, difficulty))
            link->cycle(count, difficulty);
          coop::Vitals mine;
          if (const uint64_t now = GetTickCount64(); chatting && now >= next_vitals) {
            uint64_t took_us = 0;
            if (coop::pose::local_vitals(mine, took_us)) {
              mine[coop::vital::zone] = ours;
              link->vitals(mine);
            }
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
    coop::pose::options_pass(linked); // The game's popups off while a peer is linked.
    said = coop::pose::debug_pass(linked, coop_marker, GetTickCount64());
    if (loaded && !said.empty())
      link->notice(said);
    said = coop::pose::anim_pass();
    if (loaded && !said.empty())
      link->notice(said);
    said = coop::pose::bike_pass();
    if (loaded && !said.empty())
      link->notice(said);
    said = coop::pose::race_pass();
    if (loaded && !said.empty())
      link->notice(said);
    coop::pose::hud_pass();
    coop::pose::teamshop_pass();
    coop::pose::sboxion_pass();
    coop::pose::photohunt_pass();
    coop::pose::loading_pass();
    coop::pose::sky_pass();
    if (const std::string kept = coop::pose::keep_pass(); !kept.empty())
      event(kept);
    if (const std::string theater = coop::pose::theater_pass(); !theater.empty())
      event(theater);
    // Channel 2 both ways (none in a match lobby). The shared quests take their SBQ lines out first, by sender: on the
    // host, one quest::Host per guest past the handshake; on a guest, the host's only. The shared world (SBW lines),
    // story together (SBS lines) and the shared fight (the rest) run within the pair only (partner(): the host and the
    // guest in ghost slot 0): they read the pair's lines and send theirs to the pair alone. Every other guest's game
    // keeps those three off (its partner() is 0). The lobby owner hosts the quests, the world's catch-up (its values
    // win a conflict), the story and the fight. Ours are queued for the next tick. Lines from any other member are
    // dropped. While our zone or the pair's is a solo area (Link::solo_pair: a Boss Challenge, a NIKKE stage, a
    // training room, the Matrix 11 demo room, a test zone), story together and the shared fight read the pair as
    // unlinked, as on another map: the pair's SBS and fight lines are dropped and theirs send nothing. The world and
    // the quests go on.
    names_watch(linked);
    std::vector<coop::FightLine> fights = loaded ? link->take_fight() : std::vector<coop::FightLine>();
    // Asset names (SBA lines) come from every member: each goes to its sender's ghost slot, out of what the shared
    // quests, world, story and fight read.
    const std::string names_tag = coop::asset_tag() + " ";
    fights.erase(std::remove_if(fights.begin(), fights.end(),
                                [&](const coop::FightLine &l) {
                                  if (l.line.compare(0, names_tag.size(), names_tag) != 0)
                                    return false;
                                  const int slot = link->slot_of(l.from);
                                  coop::pose::asset_line_in(slot < 0 ? coop::kMaxRemote : size_t(slot), l.line);
                                  return true;
                                }),
                 fights.end());
    const uint64_t partner = linked ? link->partner() : 0;
    const bool shared = partner != 0;
    const bool solo = linked && link->solo_pair(ours);
    const uint64_t pair_now = solo ? 0 : partner;
    // A guest the let line names the pair: once the pair before her left, the host moved her ghost to slot 0, which
    // holds no table of hers yet, so ours goes to every member at once (at a session's start, one table more). Our
    // asset names go to every member again from the first: the other members drop the lines they already have.
    if (partner && partner != was_pair && !link->host()) {
      coop::pose::table_again();
      names_sent.clear(); // Our asset names too: the host's slot 0 forgot them (names_watch()).
    }
    was_pair = partner;
    if (solo != pair_paused)
      event(solo ? "online play paused toward the pair: a solo area" : "online play resumed toward the pair");
    pair_paused = solo;
    std::vector<uint64_t> mates;
    if (linked && !link->match())
      mates = link->host() ? link->members() : std::vector<uint64_t>(link->leader() ? 1 : 0, link->leader());
    coop::pose::quest_pass(
        GetTickCount64(), !mates.empty() && link->host(), mates, partner, coop_marker, fights,
        [](const std::string &line, uint64_t to) { return link && to && link->send_fight(line, true, to); },
        quest_files);
    std::vector<std::string> channel2 = coop::lines_from(fights, partner);
    coop::pose::world_pass(partner, shared && link->host(), link && link->match(), channel2,
                           [](const std::string &line) {
                             const uint64_t pair = link ? link->partner() : 0;
                             return pair && link->send_fight(line, true, pair);
                           });
    if (solo) // world_pass took its SBW lines out: the rest are the pair's SBS and fight lines.
      channel2.clear();
    // Phase 3's boss QTE: the fight's owners and our spectating go to story; its ended QTE scenes to the fight.
    std::vector<uint32_t> qte_ended;
    coop::pose::story_pass(
        pair_now, pair_now && link->host(), link && link->match(), channel2,
        [](const std::string &line) {
          const uint64_t pair = link ? link->partner() : 0;
          return !pair_paused && pair && link->send_fight(line, true, pair);
        },
        coop::pose::fight_qte_owners(), coop::pose::fight_spectating(), qte_ended);
    bool fighting = coop::pose::fight_pass(
        GetTickCount64(), pair_now != 0, pair_now && link->host(), coop_marker, channel2,
        [](const std::string &line, bool reliable) {
          const uint64_t pair = link ? link->partner() : 0;
          return !pair_paused && pair && link->send_fight(line, reliable, pair);
        },
        pair_now ? link->mate_life() : coop::Life::unknown, pair_now, qte_ended, coop::pose::story_together());
    streaming = streaming || fighting;
    names_pass(linked);
    // Every send passes here, worker_poll's and worker_stream's before this pass's ready(): none once Steam shut down.
    coop::pose::peer(
        linked ? link->slots() : 0, GetTickCount64(),
        [](const uint8_t *d, size_t n, bool reliable) {
          if (api.user_handle())
            link->send_binary(d, n, reliable);
        },
        linked ? link->pose_cap() : coop::kPoseCaps[0]);
    write_shared();
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
                               L"coop-night.txt", L"coop-parked.txt", L"coop-cns.txt", L"coop-cns-packs.txt",
                               L"coop-shared-assets.txt",
                               L"coop-drone.txt", L"coop-names.txt", L"coop-loaded.txt"})
    DeleteFileW((folder + stale).c_str()); // Tables, addresses and a run's line from a previous run mean nothing now.
  for (size_t k = 1; k < coop::kMaxRemote; ++k) // And those of the other ghost slots.
    for (const char *stem : {"coop-remote", "coop-display", "coop-names", "coop-loaded"})
      DeleteFileW((folder + wide(coop::pose::slot_file(stem, k))).c_str());
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
