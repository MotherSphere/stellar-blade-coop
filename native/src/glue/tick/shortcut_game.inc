// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- coop shortcut: the cut Load Shortcut menu's saves, read through SB's file manager (save/shortcut.h) ----
// The calls FUN_1422907c0 makes for the menu's own list: IFileManager::Get()'s object (FUN_142820e70 returns its
// function-local static at 0x14710a7a8, made at startup, vtable 0x145f5c9a0), its CreateFileReader at vtable +0x18
// (FUN_142811eb0: flags 0, so a file that is not there gives null and no fatal error), then the reader's
// (FArchiveFileReaderGeneric, vtable 0x145f5bc60) TotalSize +0x30 (its Size at +0xa8), Serialize +0x150, Close +0x1b8
// (false after a read error) and its deleting destructor +0 with 1. Both vtables are checked before their slots are
// called. One file a frame on the game thread, where the menu reads them too, into our own buffer, under the list's
// own SEH latch: its first fault ends coop shortcut for the run.
constexpr uint64_t kFileManager = 0x14710a7a8, kFileManagerVtable = 0x145f5c9a0, kReaderVtable = 0x145f5bc60;
constexpr size_t kCreateReader = 0x18, kTotalSize = 0x30, kSerialize = 0x150, kClose = 0x1b8;
using CreateReader = void *(*)(void *manager, const wchar_t *path, uint32_t flags);
using TotalSize = int64_t (*)(void *reader);
using Serialize = void (*)(void *reader, void *data, int64_t n);
using CloseReader = bool (*)(void *reader); // The return is a bool in AL.
using DeleteReader = void *(*)(void *reader, uint32_t flags);
// The worker's asks; the game thread's word back: the ask it serves << 8 | the files read for it so far, published
// after each one's entry; the entries, each written by the game thread before the word counts it and read by the
// worker only below that count, for that ask; the latch.
std::atomic<uint32_t> shortcut_asked{0}, shortcut_word{0};
shortcut::Entry shortcut_entries[shortcut::kFiles];
std::atomic<bool> shortcut_faulted{false};
std::atomic<uint64_t> shortcut_fault_code{0}, shortcut_fault_rva{0}, shortcut_fault_address{0};
uint32_t shortcut_taken = 0; // The game thread's: the ask it serves.
int shortcut_next = shortcut::kFiles;
// The function in an object's vtable at offset.
template <class F> F virtual_at(uintptr_t object, size_t offset) {
  return reinterpret_cast<F>(at<uintptr_t>(at<uintptr_t>(object) + offset));
}
// One file into its entry: opened, its bytes read into our buffer, the reader closed and freed, then save/shortcut.h's
// parse. Out of line, since clang-cl catches a fault only in a function the __try calls.
__declspec(noinline) void shortcut_read(int file, shortcut::Entry &e) {
  e = shortcut::Entry();
  const uintptr_t manager = base + (kFileManager - game::kImageBase);
  if (at<uintptr_t>(manager) != base + (kFileManagerVtable - game::kImageBase)) {
    e.found = true, e.why = "unread: the file manager is not the pinned build's";
    return;
  }
  const std::wstring path = shortcut::path(file);
  void *reader = virtual_at<CreateReader>(manager, kCreateReader)(reinterpret_cast<void *>(manager), path.c_str(), 0);
  if (!reader)
    return; // No such file.
  e.found = true;
  const uintptr_t r = reinterpret_cast<uintptr_t>(reader);
  if (at<uintptr_t>(r) != base + (kReaderVtable - game::kImageBase)) {
    virtual_at<DeleteReader>(r, 0)(reader, 1);
    e.why = "unread: the file reader is not the pinned build's";
    return;
  }
  const int64_t size = virtual_at<TotalSize>(r, kTotalSize)(reader);
  std::string bytes;
  if (size > 0 && uint64_t(size) <= shortcut::kMaxFile) {
    bytes.resize(size_t(size));
    virtual_at<Serialize>(r, kSerialize)(reader, &bytes[0], size);
  }
  const bool read = virtual_at<CloseReader>(r, kClose)(reader);
  virtual_at<DeleteReader>(r, 0)(reader, 1);
  e.size = uint64_t(size > 0 ? size : 0);
  if (bytes.empty())
    e.why = "unread: empty or over 64 MB";
  else if (!read)
    e.why = "unread: the file manager's read failed";
  else
    shortcut::parse(std::move(bytes), e);
}
void shortcut_tick() {
  if (const uint32_t asked = shortcut_asked; asked != shortcut_taken) {
    shortcut_taken = asked;
    shortcut_next = 0;
    shortcut_word = asked << 8;
  }
  if (shortcut_next >= shortcut::kFiles)
    return;
  const int file = shortcut_next++;
  __try {
    shortcut_read(file, shortcut_entries[file]);
  } __except (fault_filter(GetExceptionInformation(), shortcut_fault_code, shortcut_fault_rva,
                           shortcut_fault_address)) {
    shortcut_faulted = true;
    return;
  }
  shortcut_word = shortcut_taken << 8 | uint32_t(file + 1);
}
} // namespace
} // namespace coop::pose
