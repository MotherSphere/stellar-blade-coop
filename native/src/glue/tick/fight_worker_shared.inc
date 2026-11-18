// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// What other modules' parts read of fight/enemies/fight_worker.inc, cut from it whole and in order.
// tick.cpp includes this file right before it.
namespace coop::pose {
namespace {
// Why the shared fight may not run now, or empty: the pinned build, before coop off, on a co-op save (a save loaded
// from the co-op copies, or the slot the game entered is the one StellarCoopSlot.txt names: slot=coop). Off a co-op
// save the reason starts with fight::kNoCoopSave, which coop fight on waits out.
std::string fight_gate(int marker) {
  if (!pinned)
    return engine_reason;
  if (blocked)
    return "coop off";
  const std::string where = slot::line(loaded_slot(), marker, lua.world, saves_now());
  return where.rfind("slot=coop ", 0) == 0 ? std::string() : std::string(fight::kNoCoopSave) + " (" + where + ")";
}
// Where a fault (fault_filter's rva) was: in an SB call, its address as the decompiles name it; in this DLL, its
// offset; else (ntdll under ApplyStat's heap, say) the address itself.
std::string fault_where(uint64_t rva) {
  const uint64_t at_address = rva + reinterpret_cast<uintptr_t>(&__ImageBase);
  char where[64];
  if (at_address - base < kSizeOfImage)
    std::snprintf(where, sizeof where, "the game at 0x%llx",
                  static_cast<unsigned long long>(at_address - base + game::kImageBase));
  else if (fault_in_dll(rva))
    std::snprintf(where, sizeof where, "StellarCoop.dll+0x%llx", static_cast<unsigned long long>(rva));
  else
    std::snprintf(where, sizeof where, "0x%llx (another module)", static_cast<unsigned long long>(at_address));
  return where;
}
enum class Filter : uint8_t { untried, on, refused, off };
std::string slot_value(uint64_t value) {
  char text[64];
  if (value - base < kSizeOfImage)
    std::snprintf(text, sizeof text, "0x%llx in the game",
                  static_cast<unsigned long long>(value - base + game::kImageBase));
  else
    std::snprintf(text, sizeof text, "0x%llx outside the game", static_cast<unsigned long long>(value));
  return text;
}
// The compare-and-swap of a slot (its address as the decompiles name it) from from to to, its page writable for the
// store only: what the slot held (from when the swap was made), or false when the page's protection would not change.
bool swap_slot(uint64_t at, uint64_t from, uint64_t to, uint64_t &held) {
  void *const slot = reinterpret_cast<void *>(base + (at - game::kImageBase));
  DWORD old = 0;
  if (!VirtualProtect(slot, sizeof(uint64_t), PAGE_READWRITE, &old))
    return false;
  held = static_cast<uint64_t>(InterlockedCompareExchange64(static_cast<volatile LONG64 *>(slot),
                                                            static_cast<LONG64>(to), static_cast<LONG64>(from)));
  VirtualProtect(slot, sizeof(uint64_t), old, &old);
  return true;
}
} // namespace
} // namespace coop::pose
