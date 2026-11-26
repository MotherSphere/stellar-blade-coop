// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The keyboard keys and mouse buttons held now, as coop_keys (glue/tick.cpp) hands them to Lua, free of Windows. UE4SS's
// binds see a key's press only: the closet camera reads its held keys here (right mouse drag orbits, middle mouse drag
// pans, I, J, K, L, U and O held orbit and zoom, Shift + I, J, K, L pans). tests/native/ui/keys_test.cpp checks this
// file on the build machine.
#pragma once

#include <array>
#include <cstddef>

namespace coop {

// Win32 virtual-key codes in bit order (bit 0 first): VK_RBUTTON 0x02, VK_MBUTTON 0x04, VK_SHIFT 0x10, then the
// letters, whose codes are their upper-case ASCII. glue/tick.cpp checks the first three against windows.h.
inline constexpr std::array<int, 9> kHeldKeys = {0x02, 0x04, 0x10, 'I', 'J', 'K', 'L', 'U', 'O'};

// 1 + one bit for each key of kHeldKeys that held(code) says is held (512 at most); 1 alone when no window of SB's is
// in front.
template <class Held> int held_keys(bool front, Held &&held) {
  if (!front)
    return 1;
  int bits = 0;
  for (size_t i = 0; i < kHeldKeys.size(); ++i)
    if (held(kHeldKeys[i]))
      bits |= 1 << i;
  return 1 + bits;
}

} // namespace coop
