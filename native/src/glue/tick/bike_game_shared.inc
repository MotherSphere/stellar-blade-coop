// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// What the keep (glue/tick/keep_game.inc) reads of vehicles/bike/bike_game.inc, cut from it whole and in order: the
// bike's async-load types and its name and find calls. tick.cpp includes this file and keep_game.inc right before it.
namespace coop::pose {
namespace {
struct SoftPath { // FSoftObjectPath: the asset's FName, then its sub-path FString (empty).
  uint64_t name;
  FStringArg sub;
};
static_assert(sizeof(SoftPath) == bike::kSoftPath);
struct PathsArg { // TArray<FSoftObjectPath> as the call takes it by value: data (GMalloc's), ArrayNum, ArrayMax.
  SoftPath *data;
  int32_t num, max;
};
using RequestAsyncLoad = void *(*)(uintptr_t manager, uintptr_t *handle_out, PathsArg *paths, uint64_t *delegate,
                                   int32_t priority, uint8_t manage, uint8_t stalled, FStringArg *debug_name);
using ResolveObject = uintptr_t (*)(const SoftPath *path);

// FName's MakeWithNumber of text: FNAME_Add (1) for a path, FNAME_Find (0) for an action name (none when SB never made
// it); 0 for NAME_None. rows/rows.h's split_number gives SB's own split of a trailing number.
uint64_t bike_name(const char *text, int find_type) {
  wchar_t wide[anim::kMaxPath + 1];
  const size_t len = std::strlen(text);
  if (!len || len > anim::kMaxPath)
    return 0;
  const lion::NameParts p = lion::split_number(text);
  for (size_t k = 0; k < p.len; ++k)
    wide[k] = wchar_t(uint8_t(text[k]));
  wide[p.len] = 0;
  const NameView view{wide, uint32_t(p.len), false};
  uint64_t out = 0;
  game_function<MakeName>(kMakeName)(&out, &view, find_type, p.number);
  return uint32_t(out) && uint32_t(out) != at<uint32_t>(base + (world::kNoneName - game::kImageBase)) ? out : 0;
}
// The object at an object path while it is in memory, else 0: SB's FSoftObjectPath::ResolveObject finds and never
// loads (game/bike.h).
uintptr_t bike_find(const char *path) {
  const SoftPath soft{bike_name(path, 1), {}};
  return soft.name ? game_function<ResolveObject>(bike::kResolveObject)(&soft) : 0;
}
} // namespace
} // namespace coop::pose
