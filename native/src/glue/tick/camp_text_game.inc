// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- Matrix XIII's camp names, the game thread's add to StringTable_UI (game/camp_text.h) ----
// Every 250 ms, at the title too, with coop off too (the entries stay for the run and a language change still needs
// them rewritten): the culture, read here with no Lua round trip, then a pass when game/camp_text.h's Pass says so. The
// pass waits while the table is missing or not loaded. It adds each absent entry the way ImportStrings does
// (14285a4f2-14285a643) and assigns each present one, which is what a language change finds. Out of line under its own
// SEH latch: the first fault ends the passes for the run, the handler lets go of the locks this code took, and the
// line says camptext=fault. A fault inside GetDisplayString can leave the manager's own lock held, as with every other
// game call in the mod.
struct SharedRef { // A TSharedPtr: the object and its controller.
  uintptr_t object = 0, controller = 0;
};
struct TextKeyOut { // An FTextKey: an interned string and its hash; nothing to destroy.
  const void *text = nullptr;
  uint32_t hash = 0;
};
using SingletonGet = uintptr_t (*)();
using FindTable = void (*)(void *registry, SharedRef *out, uint64_t id);
using FindEntry = void (*)(void *table, SharedRef *out, const FStringArg *key);
using TextKey = void (*)(TextKeyOut *out, const void *text);
using DisplayString = void (*)(void *manager, SharedRef *out, const TextKeyOut *ns, const TextKeyOut *key,
                               const FStringArg *source);
using CopyString = FStringArg *(*)(FStringArg *out, const FStringArg *source);
using MakeEntry = void (*)(SharedRef *out, SharedRef *owner, FStringArg *source, SharedRef *display);
using AddKey = void (*)(void *map, const FStringArg *key, const SharedRef *entry);
using AddDisplay = void (*)(void *map, SharedRef *display, const FStringArg *key);
using AssignString = void (*)(void *target, const FStringArg *source);
using DestroyObject = void (*)(uintptr_t controller);
using DestroyController = void (*)(uintptr_t controller, uint32_t free_it);
std::atomic<bool> camp_text_faulted{false}, camp_text_ready{false};
std::atomic<uint64_t> camp_text_fault_code{0}, camp_text_fault_rva{0}, camp_text_fault_address{0};
camp_text::Pass camp_text_pass;
uint64_t camp_text_next = 0;
void *camp_text_table_lock = nullptr, *camp_text_manager_lock = nullptr; // Held now: the handler lets them go.

// A key or a name as the calls read it: never moved or freed by them.
FStringArg camp_text_view(const char16_t *text) {
  const int32_t num = int32_t(std::char_traits<char16_t>::length(text)) + 1;
  return {text, num, num};
}
volatile long *camp_text_count(uintptr_t controller, size_t count) {
  return reinterpret_cast<volatile long *>(controller + count);
}
// SharedPointerInternals' release, as SB's code inlines it (14285a587-14285a5b3).
void camp_text_release(uintptr_t controller) {
  if (!controller || _InterlockedExchangeAdd(camp_text_count(controller, camp_text::kStrong), -1) != 1)
    return;
  const uintptr_t *vtable = at<const uintptr_t *>(controller);
  reinterpret_cast<DestroyObject>(vtable[0])(controller);
  if (_InterlockedExchangeAdd(camp_text_count(controller, camp_text::kWeak), -1) == 1)
    reinterpret_cast<DestroyController>(vtable[1])(controller, 1);
}
// One absent entry into the table, under its lock. table: the object and controller of the table.
void camp_text_add(const SharedRef &table, uintptr_t manager, const FStringArg &key, const FStringArg &text) {
  const auto text_key = game_function<TextKey>(camp_text::kTextKey);
  TextKeyOut ns, id;
  text_key(&ns, reinterpret_cast<const void *>(table.object + camp_text::kNamespace));
  text_key(&id, &key);
  SharedRef display, entry;
  game_function<DisplayString>(camp_text::kDisplayString)(reinterpret_cast<void *>(manager), &display, &ns, &id, &text);
  FStringArg source{};
  FStringArg *const copied = game_function<CopyString>(camp_text::kCopy)(&source, &text);
  SharedRef owner = table; // The factory takes one strong count of it, and all of display and source.
  _InterlockedIncrement(camp_text_count(table.controller, camp_text::kStrong));
  game_function<MakeEntry>(camp_text::kMakeEntry)(&entry, &owner, copied, &display);
  game_function<AddKey>(camp_text::kAddKey)(reinterpret_cast<void *>(table.object + camp_text::kKeys), &key, &entry);
  SharedRef shown{at<uintptr_t>(entry.object + camp_text::kEntryDisplay),
                  at<uintptr_t>(entry.object + camp_text::kEntryDisplayRef)};
  if (shown.controller)
    _InterlockedIncrement(camp_text_count(shown.controller, camp_text::kStrong));
  const auto add_display = game_function<AddDisplay>(camp_text::kAddDisplay);
  add_display(reinterpret_cast<void *>(table.object + camp_text::kDisplays), &shown, &key);
  camp_text_release(shown.controller); // As ImportStrings does (14285a643): what the emplace left, if anything.
  camp_text_release(entry.controller);
}
// One present entry in the other language, under the manager's lock since its display string is the manager's.
void camp_text_assign(const SharedRef &entry, uintptr_t manager, const FStringArg &text) {
  const auto assign = game_function<AssignString>(camp_text::kAssign);
  camp_text_manager_lock = reinterpret_cast<void *>(manager + camp_text::kManagerLock);
  EnterCriticalSection(static_cast<LPCRITICAL_SECTION>(camp_text_manager_lock));
  const uintptr_t display = at<uintptr_t>(entry.object + camp_text::kEntryDisplay);
  if (game::plausible(display))
    assign(reinterpret_cast<void *>(display), &text);
  assign(reinterpret_cast<void *>(entry.object + camp_text::kEntrySource), &text);
  LeaveCriticalSection(static_cast<LPCRITICAL_SECTION>(camp_text_manager_lock));
  camp_text_manager_lock = nullptr;
}
__declspec(noinline) void camp_text_body() {
  if (!game::plausible(at<uintptr_t>(base + (camps::kMallocAt - game::kImageBase))))
    return; // The calls below allocate, and FMemory's calls make GMalloc when null.
  const uintptr_t intl = game_function<SingletonGet>(camp_text::kInternationalization)();
  const uintptr_t culture = game::plausible(intl) ? at<uintptr_t>(intl + camp_text::kCulture) : 0;
  if (!game::plausible(culture))
    return;
  const bool french = camp_text::french(at<const char16_t *>(culture + camp_text::kCultureName),
                                        at<int32_t>(culture + camp_text::kCultureNameNum));
  if (!camp_text_pass.due(french))
    return;
  const uintptr_t holder = game_function<SingletonGet>(camp_text::kManagerHolder)();
  const uintptr_t manager = game::plausible(holder) ? at<uintptr_t>(holder + camp_text::kManager) : 0;
  const uintptr_t registry = game_function<SingletonGet>(camp_text::kRegistry)();
  if (!game::plausible(manager) || !game::plausible(registry))
    return;
  const NameView id_view{camp_text::kTableId, uint32_t(wcslen(camp_text::kTableId)), false};
  uint64_t id = 0;
  game_function<MakeName>(kMakeName)(&id, &id_view, 1, 0); // 1: FNAME_Add. The table's name has no number suffix.
  SharedRef table;
  game_function<FindTable>(camp_text::kFindTable)(reinterpret_cast<void *>(registry), &table, id);
  if (game::plausible(table.object) && at<uint8_t>(table.object + camp_text::kLoaded)) {
    camp_text_table_lock = reinterpret_cast<void *>(table.object + camp_text::kTableLock);
    EnterCriticalSection(static_cast<LPCRITICAL_SECTION>(camp_text_table_lock));
    for (const camp_text::Entry &e : camp_text::kEntries) {
      const FStringArg key = camp_text_view(e.key), text = camp_text_view(french ? e.french : e.english);
      SharedRef found;
      game_function<FindEntry>(camp_text::kFindEntry)(reinterpret_cast<void *>(table.object), &found, &key);
      if (found.object)
        camp_text_assign(found, manager, text);
      else
        camp_text_add(table, manager, key, text);
      camp_text_release(found.controller);
    }
    LeaveCriticalSection(static_cast<LPCRITICAL_SECTION>(camp_text_table_lock));
    camp_text_table_lock = nullptr;
    camp_text_pass.done(french);
    camp_text_ready = true;
  }
  camp_text_release(table.controller);
}
void camp_text_tick() {
  const uint64_t now = GetTickCount64();
  if (now < camp_text_next)
    return;
  camp_text_next = now + camp_text::kCheckMs;
  __try {
    camp_text_body();
  } __except (fault_filter(GetExceptionInformation(), camp_text_fault_code, camp_text_fault_rva,
                           camp_text_fault_address)) {
    if (camp_text_manager_lock)
      LeaveCriticalSection(static_cast<LPCRITICAL_SECTION>(camp_text_manager_lock));
    if (camp_text_table_lock)
      LeaveCriticalSection(static_cast<LPCRITICAL_SECTION>(camp_text_table_lock));
    camp_text_faulted = true; // camp_text_status() then says camptext=fault; the rows keep what they hold.
  }
}
} // namespace
} // namespace coop::pose
