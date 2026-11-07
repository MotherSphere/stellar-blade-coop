// The between-regions teleport screen's extra tabs (ui/region_tabs.lua makes them). WB_AreaTeleport_Set holds 7 tabs,
// and SB's Region logic (type 0xBC, vtable 0x145c44948) serves only the tabs that have a child logic node of type 0xBD.
// Nodes come from a list of 0x2C records that FUN_142533870 builds from the widget's class properties, so a tab made at
// run time has none. FUN_141fc8f40 builds the root node, calls its vtable +0x30 and only then reads that list, so one
// record added in that call gives a made tab its node, its place in the array and its camp through SB's own code. The
// address and offsets are for Stellar Blade's Steam build 26123051. This part has no Windows call:
// glue/tick/region_tabs_worker.inc makes the game calls.
#pragma once

#include <cstddef>
#include <cstdint>

namespace coop::region_tabs {

constexpr uint64_t kSlot = 0x145c44978;       // .rdata: the Region logic's vtable +0x30.
constexpr uint64_t kInit = 0x141f6a560;       // What the slot holds: the Region logic's init (resets its fields).
constexpr uint64_t kRootReturn = 0x141fc9041; // The call for the root node. 0x141fc91c2, a child's, holds a pointer
                                              // into the list that a grow would leave dangling.
constexpr uint64_t kManagers = 0x141a98bc0, kWidgetByGuid = 0x141e3c220, kChildByName = 0x14253d3a0,
                   kGuidOf = 0x14226eeb0, kGrow = 0x1418fc4e0, kPanelPath = 0x142537020;
// From the hook's return address to FUN_141fc8f40's fifth argument, the list's address: that function's [rbp+0x50],
// which it reads again after the call (0x141fc907a).
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
struct Record { // One entry as FUN_142535e00 writes it (0x142536120-0x14253613f).
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
// As FUN_142535e00 does (0x142536106-0x142536118): the count up, then the grow, which reads the new count.
template <class Grow> void append(Records &r, const Record &record, Grow &&grow) {
  const int32_t at = r.num++;
  if (r.num > r.max)
    grow(&r);
  r.data[at] = record;
}

} // namespace coop::region_tabs
