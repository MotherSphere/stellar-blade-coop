// Part of glue/tick.cpp, one translation unit with it (see there).
// The between-regions teleport screen's extra tabs (game/region_tabs.h): the slot's hook, on the game thread, and the
// worker's swap, undo and log.

namespace coop::pose {
namespace {
// One aligned 8-byte store into the Region logic's vtable, as the spawn filter does (fight_worker.inc): no instruction
// byte of the game changes. The worker makes it once a run by a compare-and-swap from kInit only, and undoes it at coop
// off and after a fault by a compare-and-swap from our hook only, so another mod's value is never overwritten. The DLL
// is pinned, so a thread still inside the hook after the undo is safe. A tab that got no record stays collapsed:
// ui/region_tabs.lua makes every tab collapsed and only SB's camp list, through the logic, shows one.
using RegionInit = void *(*)(void *logic, void *arg);
using RegionManagers = uintptr_t (*)();
using RegionWidget = uintptr_t (*)(uintptr_t manager, const region_tabs::Guid *guid);
using RegionChild = uintptr_t (*)(uintptr_t widget, const uint64_t *name);
using RegionGuidOf = region_tabs::Guid *(*)(uintptr_t manager, region_tabs::Guid *out, uintptr_t widget);
using RegionGrow = void (*)(region_tabs::Records *records);
using RegionPath = void (*)(uintptr_t widget);
Filter region_state = Filter::untried; // The worker's.
std::atomic<bool> region_faulted{false};
std::atomic<uint64_t> region_fault_code{0}, region_fault_rva{0}, region_fault_address{0};
// The last open, for the worker's log line: its logic, the list's count after our records, and how many were ours;
// logic last, so the others are written once it is set.
std::atomic<uint32_t> region_records{0}, region_added{0};
std::atomic<uintptr_t> region_logic{0};
bool region_fault_logged = false, region_logged = false;
uint64_t region_log_at = 0;

// A record for each tab of the screen's panel that has none: its class as the panel's first tab that has one, its
// parent the screen. Changes nothing when no panel child is in the list (the wrong list, or a screen of another build).
__declspec(noinline) void region_tabs_body(uintptr_t logic, region_tabs::Records *records) {
  using namespace region_tabs;
  if (!game::plausible(reinterpret_cast<uintptr_t>(records)) || !sane(*records))
    return;
  const uintptr_t node = at<uintptr_t>(logic + kLogicNode);
  const uintptr_t holder = game_function<RegionManagers>(kManagers)();
  const uintptr_t manager = game::plausible(holder) ? at<uintptr_t>(holder + kManagerWidgets) : 0;
  if (!game::plausible(node) || !game::plausible(manager))
    return;
  const Guid screen_guid = at<Guid>(node + kNodeGuid);
  const uintptr_t screen = game_function<RegionWidget>(kWidgetByGuid)(manager, &screen_guid);
  if (!game::plausible(screen))
    return;
  const NameView view{kPanel, uint32_t(wcslen(kPanel)), false};
  uint64_t panel_name = 0;
  game_function<MakeName>(kMakeName)(&panel_name, &view, 1, 0); // 1: FNAME_Add. The name has no number suffix.
  const uintptr_t panel = game_function<RegionChild>(kChildByName)(screen, &panel_name);
  if (!game::plausible(panel))
    return;
  const uintptr_t slots = at<uintptr_t>(panel + kPanelSlots);
  const int32_t count = at<int32_t>(panel + kPanelSlotCount);
  if (!game::plausible(slots) || count <= 0 || count > kMaxRecords)
    return;
  const auto content = [slots](int32_t i) {
    const uintptr_t slot = at<uintptr_t>(slots + size_t(i) * sizeof(uintptr_t));
    return game::plausible(slot) ? at<uintptr_t>(slot + kSlotContent) : uintptr_t(0);
  };
  uintptr_t tab_class = 0;
  for (int32_t i = 0; i < count && !tab_class; ++i)
    if (const uintptr_t child = content(i); game::plausible(child) && has(*records, at<uint64_t>(child + kObjectName)))
      tab_class = at<uintptr_t>(child + kObjectClass);
  if (!tab_class)
    return;
  uint32_t added = 0;
  for (int32_t i = 0; i < count; ++i) {
    const uintptr_t child = content(i);
    if (!game::plausible(child) || at<uintptr_t>(child + kObjectClass) != tab_class ||
        at<uintptr_t>(child + kWidgetParent) != screen || has(*records, at<uint64_t>(child + kObjectName)))
      continue;
    // What FUN_142535e00 does for a class property's widget: its logic type, which its notifies climb to, and its path.
    *reinterpret_cast<uint32_t *>(child + kWidgetLogic) = kTabLogic;
    game_function<RegionPath>(kPanelPath)(child);
    Guid guid{};
    game_function<RegionGuidOf>(kGuidOf)(manager, &guid, child);
    append(*records, Record{at<uint64_t>(child + kObjectName), guid, kTabLogic, screen_guid},
           game_function<RegionGrow>(kGrow));
    ++added;
  }
  region_records = uint32_t(records->num);
  region_added = added;
  region_logic = logic;
}
// The slot's target once swapped. Only the root's call reads the list after it; the game's function runs outside the
// guard, so a fault in its own code is never taken for ours. kInit reads its first argument only.
void *region_tabs_init(void *logic, void *arg) {
  const uint64_t root_call = base + (region_tabs::kRootReturn - game::kImageBase);
  if (!region_faulted && reinterpret_cast<uintptr_t>(_ReturnAddress()) == root_call) {
    auto **const stack = static_cast<region_tabs::Records **>(_AddressOfReturnAddress());
    __try {
      region_tabs_body(reinterpret_cast<uintptr_t>(logic), stack[region_tabs::kRecordsAt / sizeof(void *)]);
    } __except (fault_filter(GetExceptionInformation(), region_fault_code, region_fault_rva, region_fault_address)) {
      region_faulted = true;
    }
  }
  return game_function<RegionInit>(region_tabs::kInit)(logic, arg);
}
uint64_t region_init_address() { return base + (region_tabs::kInit - game::kImageBase); }
uint64_t region_hook_address() { return reinterpret_cast<uintptr_t>(&region_tabs_init); }
// Once a run, on the worker thread, on the pinned build before coop off. A slot that holds anything else is refused and
// never written: the screen keeps its 7 tabs.
void region_tabs_install() {
  const uint64_t init = region_init_address();
  uint64_t held = *reinterpret_cast<const volatile uint64_t *>(base + (region_tabs::kSlot - game::kImageBase));
  const bool slot_ok = held == init;
  const bool page_ok = slot_ok && swap_slot(region_tabs::kSlot, init, region_hook_address(), held);
  const bool on = page_ok && held == init;
  region_state = on ? Filter::on : Filter::refused;
  if (on)
    say("region tabs on: 0x145c44978 swapped from the Region logic's init to our hook");
  else if (slot_ok && !page_ok)
    say("region tabs refused: the page of 0x145c44978 would not become writable (error " +
        std::to_string(GetLastError()) + "); the teleport screen keeps its 7 tabs");
  else
    say("region tabs refused: 0x145c44978 holds " + slot_value(held) +
        ", not the Region logic's init (another mod's hook?); left as it is, the teleport screen keeps its 7 tabs");
}
// The slot back by a compare-and-swap from our hook only. If the swap cannot be made the hook stays: after coop off Lua
// makes no more tabs, so it finds none, and after a fault its latch sends every call straight on.
void region_tabs_undo(const char *why) {
  if (region_state != Filter::on)
    return;
  region_state = Filter::off;
  uint64_t held = 0;
  if (!swap_slot(region_tabs::kSlot, region_hook_address(), region_init_address(), held))
    say(std::string("region tabs off (") + why +
        "): the page of 0x145c44978 would not become writable; our hook stays in it");
  else if (held == region_hook_address())
    say(std::string("region tabs off (") + why + "): 0x145c44978 holds the Region logic's init again");
  else
    say(std::string("region tabs off (") + why + "): 0x145c44978 holds " + slot_value(held) + ", left as it is");
}
// Each worker pass (from lion_pass): the swap, the hook's fault once, and one line a run for the first screen opened,
// a second later so that SB has filled its array by then. The array is read through safe_read: the screen may be gone.
void region_tabs_pass() {
  if (region_state == Filter::untried && pinned && !blocked && !region_faulted)
    region_tabs_install();
  if (region_faulted && !region_fault_logged) {
    region_fault_logged = true;
    char text[300];
    std::snprintf(text, sizeof text, "region tabs fault 0x%08llx in %s reading 0x%llx: off for this run",
                  static_cast<unsigned long long>(region_fault_code.load()), fault_where(region_fault_rva).c_str(),
                  static_cast<unsigned long long>(region_fault_address.load()));
    say(text);
    region_tabs_undo("a fault");
  }
  const uintptr_t logic = region_logic;
  if (region_logged || !logic)
    return;
  const uint64_t now = GetTickCount64();
  if (!region_log_at)
    region_log_at = now + 1000;
  if (now < region_log_at)
    return;
  region_logged = true;
  int32_t tabs = -1;
  if (!safe_read(logic + region_tabs::kLogicTabs, &tabs, sizeof tabs))
    tabs = -1;
  say("region tabs: " + std::to_string(region_added.load()) + " records added, " +
      std::to_string(region_records.load()) + " in the list, " + std::to_string(tabs) + " tabs in the Region logic");
}
} // namespace
} // namespace coop::pose
