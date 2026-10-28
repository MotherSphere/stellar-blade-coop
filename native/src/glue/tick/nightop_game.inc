// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- The Night Operation shop in SB's own shop screen (nightop/shop_ui.h), the game thread's calls ----
// The worker hands over the ask (open, open bolt, close) with its number; the next frame takes it with try_lock only,
// reads the client and its UI manager and makes the game's own find, open and init, or find and close, out of line
// under its own latch. Every kReadMs after the first ask (not after coop off), it reads whether a shop screen is open
// and, with the client in game (flow 2) and inside the rows' gate (lion_gate: net mode 0, no logic task in flight, so
// no purchase runs meanwhile), the bucket's Beta Seeds through the UI's own count. A close asked after coop off still
// runs (coop off asks it first). The first fault ends the shop screen's calls for the run. The UI manager's find, open
// and close and ui_reads are coop devinfo's (glue/tick/debug_game.inc).
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

// The game's close of a shop screen's entry, with the entry's own type, as the vending machine's node closes one.
void nightshop_close(void *manager, void *entry) {
  const uintptr_t widget = reinterpret_cast<uintptr_t>(entry) + devinfo::kEntryWidget;
  const auto type_of = reinterpret_cast<UiType>(at<uintptr_t>(at<uintptr_t>(widget) + devinfo::kTypeSlot));
  game_function<CloseUi>(devinfo::kCloseUi)(manager, type_of(reinterpret_cast<void *>(widget)));
}
// One ask's calls. Out of line, since clang-cl catches a fault only in a function the __try calls. An entry the open
// made with no shop logic is closed again, so no screen stays up that SB never set up; a fault inside ShopInit still
// leaves it up (the latch then stops every read and close).
__declspec(noinline) shopui::Why nightshop_act(uint8_t ask) {
  if (ask == shopui::kWatch)
    return shopui::Why::none;
  const shopui::Reads r = ui_reads();
  if (const shopui::Why why = shopui::refuse(r, ask != shopui::kClose); why != shopui::Why::none)
    return why;
  void *manager = reinterpret_cast<void *>(r.manager);
  void *entry = game_function<FindUi>(devinfo::kFindUi)(manager, shopui::kShopType);
  if (ask == shopui::kClose) {
    if (!entry)
      return shopui::Why::closed;
    nightshop_close(manager, entry);
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
  EmptyName empty{};
  void *opened = game_function<OpenUi>(devinfo::kOpenUi)(manager, shopui::kShopType, nullptr, nullptr, 0, &empty, 0);
  if (!opened)
    return shopui::Why::game;
  void *logic = reinterpret_cast<void *>(at<uintptr_t>(reinterpret_cast<uintptr_t>(opened) + shopui::kEntryLogic));
  if (!logic) {
    nightshop_close(manager, opened);
    return shopui::Why::logic;
  }
  game_function<ShopInit>(shopui::kShopInit)(logic, &shop, &shop, &none);
  return shopui::Why::none;
}
// The reads: a shop screen open, and with the client in game and inside the gate the bucket's seeds (unread otherwise,
// or with no player data). The reads run for the rest of the game run: flow 2 keeps the bucket getter off the title
// screen, where the world's player data may be a stale object.
__declspec(noinline) void nightshop_read() {
  const shopui::Reads r = ui_reads();
  nightshop_open = shopui::refuse(r, false) != shopui::Why::none
                       ? -1
                       : game_function<FindUi>(devinfo::kFindUi)(reinterpret_cast<void *>(r.manager),
                                                                  shopui::kShopType) != nullptr;
  uint32_t mode = 0;
  const uintptr_t world = at<uintptr_t>(base + (shopui::kWorldAt - game::kImageBase));
  const uintptr_t data = game::plausible(world) ? at<uintptr_t>(world + shopui::kPlayerData) : 0;
  if (r.flow != devinfo::kInGame || lion_gate(mode) != lion::Why::none || !game::plausible(data))
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

// ---- Roxanne's Night Operation choices and Lily's signal choice (nightop/roxanne.h), the game thread's calls ----
// For each list, the worker hands over on or off with its number; the game thread takes it with try_lock only and,
// once the rows' gate holds (refused after lion::kGateTicks shut frames), points the list's entry in SB's select cache
// at our names or puts the list's own back, out of line under the list's own latch; reads go through safe_read, the
// find and the allocation are SB's. Every kReadMs after the first ask it looks at the entry again (a game rebuild of
// the cache shows as off). After coop off only off is taken (coop off asks it first). The first fault ends that list's
// choices for the run, as they stand; the other list goes on.
struct WinRoxanneGame : WinShockGame {
  int32_t find(uint64_t map, uint64_t name) {
    int32_t index = -1;
    game_function<MapFind>(roxanne::kMapFind)(reinterpret_cast<const void *>(map), &index, name);
    return index;
  }
};
struct SwapSide {
  SwapSide(const roxanne::List &l, const char *w) : list(l), who(w) {}
  const roxanne::List &list;
  const char *who; // For the log: "Roxanne's choices", "Lily's choices".
  std::atomic<bool> faulted{false};
  std::atomic<uint64_t> fault_code{0}, fault_rva{0}, fault_address{0};
  std::mutex m; // The worker's ask: its number and on or off.
  uint32_t asked = 0;
  bool want = false;
  // The game thread's word for the worker: asks 32-63, want 24, why 16-23, shape 8-15, waiting 0.
  std::atomic<uint64_t> word{0};
  roxanne::Swap swap; // The game thread's own, with the rest below.
  uint32_t taken = 0, waited = 0, done = 0;
  bool pending = false, wanted = false;
  roxanne::Why why = roxanne::Why::none;
  uint64_t next_read = 0;
};
SwapSide roxanne_side{roxanne::kRoxanne, "Roxanne's choices"}, lily_side{roxanne::kLily, "Lily's choices"};
void swap_publish(SwapSide &side, roxanne::Shape shape) {
  side.word = uint64_t(side.done) << 32 | uint64_t(side.wanted) << 24 | uint64_t(side.why) << 16 |
              uint64_t(shape) << 8 | uint64_t(side.pending);
}
// One try at the ask: the gate, then on or off. Out of line for the __try below.
__declspec(noinline) roxanne::Why swap_body(SwapSide &side, bool on, bool &gated, roxanne::Shape &shape) {
  uint32_t mode = 0;
  const lion::Why gate = lion_gate(mode);
  gated = gate == lion::Why::none;
  WinRoxanneGame g;
  if (!gated) {
    shape = roxanne::shape(g, base, side.list, side.swap);
    return gate == lion::Why::busy ? roxanne::Why::busy : gate == lion::Why::net ? roxanne::Why::net
                                                                                 : roxanne::Why::gate;
  }
  const roxanne::Why why = on ? roxanne::arm(g, base, side.list, side.swap)
                              : (roxanne::disarm(g, base, side.list, side.swap), roxanne::Why::none);
  shape = roxanne::shape(g, base, side.list, side.swap);
  return why;
}
__declspec(noinline) roxanne::Shape swap_look(SwapSide &side) {
  WinRoxanneGame g;
  return roxanne::shape(g, base, side.list, side.swap);
}
void swap_tick(SwapSide &side) {
  bool got = false, want = false;
  uint32_t asked = 0;
  if (side.m.try_lock()) {
    asked = side.asked, want = side.want;
    side.m.unlock();
    got = asked != side.taken;
  }
  if (got) {
    side.taken = asked, side.wanted = want, side.pending = true, side.waited = 0;
    if (blocked && want) // After coop off: only off.
      side.pending = false, side.done = asked, side.why = roxanne::Why::gate;
  }
  roxanne::Shape shape = roxanne::Shape::unread;
  bool looked = false;
  if (side.pending) {
    bool gated = false;
    __try {
      side.why = swap_body(side, side.wanted, gated, shape);
    } __except (fault_filter(GetExceptionInformation(), side.fault_code, side.fault_rva, side.fault_address)) {
      side.faulted = true;
      return;
    }
    looked = true;
    if (gated || ++side.waited >= lion::kGateTicks)
      side.pending = false, side.done = side.taken;
  } else if (const uint64_t now = GetTickCount64(); side.taken && !blocked && now >= side.next_read) {
    side.next_read = now + shopui::kReadMs;
    __try {
      shape = swap_look(side);
    } __except (fault_filter(GetExceptionInformation(), side.fault_code, side.fault_rva, side.fault_address)) {
      side.faulted = true;
      return;
    }
    looked = true;
  }
  if (looked)
    swap_publish(side, shape);
}
} // namespace
} // namespace coop::pose
