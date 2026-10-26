// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- The Night Operation shop in SB's own shop screen (nightop/shop_ui.h), the game thread's calls ----
// The worker hands over the ask (open, open bolt, close) with its number; the next frame takes it with try_lock only,
// reads the client and its UI manager and makes the game's own find, open and init, or find and close, out of line
// under its own latch. Every kReadMs after the first ask (not after coop off), it reads whether a shop screen is open
// and, inside the rows' gate (lion_gate: net mode 0, no logic task in flight, so no purchase runs meanwhile), the
// bucket's Beta Seeds through the UI's own count. A close asked after coop off still runs (coop off asks it first). The
// first fault ends the shop screen's calls for the run.
using ShopFindUi = void *(*)(void *manager, int32_t type);
struct ShopEmptyString { // An FString with no data, which the open copies and frees only when it holds data.
  void *data;
  int32_t num, max;
};
static_assert(sizeof(ShopEmptyString) == 16);
using ShopOpenUi = void *(*)(void *manager, int32_t type, void *children, void *parent, uint64_t,
                             ShopEmptyString *name, uint64_t);
using ShopCloseUi = void (*)(void *manager, int32_t type);
using ShopUiType = int32_t (*)(void *widget);
using ShopInit = void (*)(void *logic, const uint64_t *shop, const uint64_t *instance, const uint64_t *title);
using ShopBucket = void *(*)(void *player_data);
using ShopCount = int32_t (*)(void *bucket, const uint64_t *item);
std::atomic<bool> nightshop_faulted{false};
std::atomic<uint64_t> nightshop_fault_code{0}, nightshop_fault_rva{0}, nightshop_fault_address{0};
std::mutex nightshop_m; // The worker's ask: its number and what.
uint32_t nightshop_asked = 0;
uint8_t nightshop_want = shopui::kClose;
std::atomic<uint64_t> nightshop_done{0};   // shopui::pack of the last ask handled.
std::atomic<int> nightshop_open{-1};       // A shop screen open at the last read: -1 unread, 0, 1.
std::atomic<int64_t> nightshop_seeds{-1};  // The bucket's Beta Seeds at the last read, -1 unread.
uint32_t nightshop_taken = 0;              // The game thread's own.
uint64_t nightshop_next_read = 0, nightshop_seed = 0;

// The client and its UI manager, and the guard's reads.
shopui::Reads nightshop_reads() {
  shopui::Reads r;
  r.client = at<uintptr_t>(base + (shopui::kClientAt - game::kImageBase));
  if (game::plausible(r.client)) {
    r.manager = at<uintptr_t>(r.client + shopui::kManager);
    r.flow = at<int32_t>(r.client + shopui::kFlow);
    r.phase = at<int32_t>(r.client + shopui::kPhase);
  }
  return r;
}
// One ask's calls. Out of line, since clang-cl catches a fault only in a function the __try calls.
__declspec(noinline) shopui::Why nightshop_act(uint8_t ask) {
  if (ask == shopui::kWatch)
    return shopui::Why::none;
  const shopui::Reads r = nightshop_reads();
  if (const shopui::Why why = shopui::refuse(r, ask != shopui::kClose); why != shopui::Why::none)
    return why;
  void *manager = reinterpret_cast<void *>(r.manager);
  void *entry = game_function<ShopFindUi>(shopui::kFindUi)(manager, shopui::kShopType);
  if (ask == shopui::kClose) {
    if (!entry)
      return shopui::Why::closed;
    const uintptr_t widget = reinterpret_cast<uintptr_t>(entry) + shopui::kEntryWidget;
    const auto type_of = reinterpret_cast<ShopUiType>(at<uintptr_t>(at<uintptr_t>(widget) + shopui::kTypeSlot));
    game_function<ShopCloseUi>(shopui::kCloseUi)(manager, type_of(reinterpret_cast<void *>(widget)));
    return shopui::Why::none;
  }
  if (entry)
    return shopui::Why::open;
  WinLionGame g;
  const char *const shop_name = shopui::kShops[ask == shopui::kOpenBolt];
  const lion::NameParts p = lion::split_number(shop_name);
  const uint64_t shop = g.name(shop_name, p.len, p.number), none = 0;
  if (!shop)
    return shopui::Why::name;
  ShopEmptyString empty{};
  void *opened = game_function<ShopOpenUi>(shopui::kOpenUi)(manager, shopui::kShopType, nullptr, nullptr, 0, &empty, 0);
  if (!opened)
    return shopui::Why::game;
  void *logic = reinterpret_cast<void *>(at<uintptr_t>(reinterpret_cast<uintptr_t>(opened) + shopui::kEntryLogic));
  if (!logic)
    return shopui::Why::logic;
  game_function<ShopInit>(shopui::kShopInit)(logic, &shop, &shop, &none);
  return shopui::Why::none;
}
// The reads: a shop screen open, and inside the gate the bucket's seeds (unread otherwise, or with no player data).
__declspec(noinline) void nightshop_read() {
  const shopui::Reads r = nightshop_reads();
  nightshop_open = shopui::refuse(r, false) != shopui::Why::none
                       ? -1
                       : game_function<ShopFindUi>(shopui::kFindUi)(reinterpret_cast<void *>(r.manager),
                                                                     shopui::kShopType) != nullptr;
  uint32_t mode = 0;
  const uintptr_t world = at<uintptr_t>(base + (shopui::kWorldAt - game::kImageBase));
  const uintptr_t data = game::plausible(world) ? at<uintptr_t>(world + shopui::kPlayerData) : 0;
  if (lion_gate(mode) != lion::Why::none || !game::plausible(data))
    return void(nightshop_seeds = -1);
  if (!nightshop_seed) {
    WinLionGame g;
    nightshop_seed = g.name(shopui::kSeed, std::strlen(shopui::kSeed), 0);
  }
  void *bucket = game_function<ShopBucket>(shopui::kBucket)(reinterpret_cast<void *>(data));
  nightshop_seeds = bucket && nightshop_seed ? game_function<ShopCount>(shopui::kCount)(bucket, &nightshop_seed) : -1;
}
void nightshop_tick() {
  uint32_t asked = 0;
  uint8_t want = shopui::kClose;
  if (nightshop_m.try_lock()) {
    asked = nightshop_asked, want = nightshop_want;
    nightshop_m.unlock();
  } else
    asked = nightshop_taken;
  if (asked != nightshop_taken) {
    nightshop_taken = asked;
    shopui::Answer a;
    a.asks = asked, a.ask = want, a.why = shopui::Why::game; // What a fault leaves.
    __try {
      a.why = nightshop_act(want);
    } __except (fault_filter(GetExceptionInformation(), nightshop_fault_code, nightshop_fault_rva,
                             nightshop_fault_address)) {
      nightshop_faulted = true;
    }
    a.done = a.why == shopui::Why::none;
    nightshop_done = shopui::pack(a);
    nightshop_next_read = 0; // Read again at once: Lua waits for the screen.
  }
  if (nightshop_faulted || !nightshop_taken || blocked)
    return;
  if (const uint64_t now = GetTickCount64(); now >= nightshop_next_read) {
    nightshop_next_read = now + shopui::kReadMs;
    __try {
      nightshop_read();
    } __except (fault_filter(GetExceptionInformation(), nightshop_fault_code, nightshop_fault_rva,
                             nightshop_fault_address)) {
      nightshop_faulted = true;
    }
  }
}
} // namespace
} // namespace coop::pose
