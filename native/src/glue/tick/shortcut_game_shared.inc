// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// What other modules' parts read of save/shortcut_game.inc, cut from it whole and in order.
// tick.cpp includes this file right before it.
namespace coop::pose {
namespace {
// The function in an object's vtable at offset.
template <class F> F virtual_at(uintptr_t object, size_t offset) {
  return reinterpret_cast<F>(at<uintptr_t>(at<uintptr_t>(object) + offset));
}
} // namespace
} // namespace coop::pose
