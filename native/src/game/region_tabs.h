// The between-regions teleport screen's extra tabs (ui/region_tabs.lua makes them). WB_AreaTeleport_Set holds 7 tabs,
// and SB's Region logic (type 0xBC, vtable 0x145c3eb08) serves only the tabs that have a child logic node of type 0xBD.
// Nodes come from a list of 0x2C records that FUN_14252de30 builds from the widget's class properties, so a tab made at
// run time has none. FUN_141fc4d20 builds the root node, calls its vtable +0x30 and only then reads that list, so one
// record added in that call gives a made tab its node, its place in the array and its camp through SB's own code. The
// address and offsets are for Stellar Blade's Steam build 24463856. This part has no Windows call:
// glue/tick/region_tabs_worker.inc makes the game calls.
#pragma once

#include <cstddef>
#include <cstdint>

namespace coop::region_tabs {

constexpr uint64_t kSlot = 0x145c3eb38;       // .rdata: the Region logic's vtable +0x30.
constexpr uint64_t kInit = 0x141f66a00;       // What the slot holds: the Region logic's init (resets its fields).
constexpr uint64_t kRootReturn = 0x141fc4e21; // The call for the root node. 0x141fc4fa2, a child's, holds a pointer
                                              // into the list that a grow would leave dangling.
constexpr uint64_t kManagers = 0x141a97cb0, kWidgetByGuid = 0x141e39bc0, kChildByName = 0x142537960,
                   kGuidOf = 0x142269830, kGrow = 0x1418fc350, kPanelPath = 0x1425315e0;
// From the hook's return address to FUN_141fc4d20's fifth argument, the list's address: that function's [rbp+0x50],
// which it reads again after the call (0x141fc4e5a).
constexpr size_t kRecordsAt = 0xb8;
constexpr size_t kLogicNode = 0x8, kLogicTabs = 0x100, kNodeGuid = 0x44, kManagerWidgets = 0x48;
constexpr size_t kObjectClass = 0x10, kObjectName = 0x18;
constexpr size_t kPanelSlots = 0x108, kPanelSlotCount = 0x110, kSlotContent = 0x30;
constexpr size_t kWidgetParent = 0x4c8, kWidgetLogic = 0x4d0;
constexpr uint32_t kTabLogic = 0xBD;
constexpr int32_t kMaxRecords = 256; // The screen has 7; more means the stack did not hold the list.
constexpr const wchar_t *kPanel = L"HB_AreaTeleportRoot";

struct Guid {
  uint32_t a, b, c, d;
};
#pragma pack(push, 4)
struct Record { // One entry as FUN_1425303c0 writes it (0x1425306e0-0x1425306ff).
  uint64_t name;
  Guid guid;
  uint32_t type;
  Guid parent;
};
#pragma pack(pop)
static_assert(sizeof(Record) == 0x2c && offsetof(Record, type) == 0x18 && offsetof(Record, parent) == 0x1c);
struct Records { // A TArray.
  Record *data;
  int32_t num, max;
};

inline bool sane(const Records &r) { return r.data && r.num > 0 && r.num <= r.max && r.num <= kMaxRecords; }
inline bool has(const Records &r, uint64_t name) {
  for (int32_t i = 0; i < r.num; ++i)
    if (r.data[i].name == name)
      return true;
  return false;
}
// As FUN_1425303c0 does (0x1425306c6-0x1425306d8): the count up, then the grow, which reads the new count.
template <class Grow> void append(Records &r, const Record &record, Grow &&grow) {
  const int32_t at = r.num++;
  if (r.num > r.max)
    grow(&r);
  r.data[at] = record;
}

} // namespace coop::region_tabs
