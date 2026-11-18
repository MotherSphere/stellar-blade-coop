// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// What other modules' parts read of save/saves_worker.inc, cut from it whole and in order.
// tick.cpp includes this file right before it.
namespace coop::pose {
int loaded_slot() { return pinned && !blocked ? slot::index(base, rpm) : slot::kUnread; }
namespace {
slot::Names names; // The save name as the worker last read it back.
// After coop off nothing is read again, but the name stays as it was until the game exits: the last value read.
slot::Saves saves_now() { return pinned ? names.saves() : slot::Saves::off; }
} // namespace
int reloading(bool after_off) {
  const int value = pinned && (after_off || !blocked) ? slot::field(base, rpm, slot::kReloading) : slot::kUnread;
  return value == slot::kUnread ? value : value & 0xff; // One byte; +0x2f9d to +0x2f9f are other flags.
}
} // namespace coop::pose
