// Part of glue/tick.cpp, one translation unit with it (see there).
// Death and revive in game (revive/local.h): revive/core.h's rules for one player, run on the worker thread over what
// each pass reads of her own EVE, and the one write her game's own death is held off by: MinimumHP (stat 107,
// fight/types.h's kMinimumHp) at its base value + 1, so ApplyStat stops a lethal hit at 1 HP. The floor and the HP a
// revive gives back are plain float writes, the ones the 2026-10-22 memory test made from outside the game (she stayed
// at 1 HP and alive under enemy hits, and died on the next hit once the floor went), so neither needs the logic
// thread. tests/native/revive/local_test.cpp checks it against a fake EVE.
#include <cmath>
#include <cstdio>
#include <cstring>

namespace coop::pose {

// A 4-byte float into the same process (revive/local.h's floor and HP). False on a refused write.
bool wpm_float(uint64_t address, float value) {
  SIZE_T put = 0;
  return WriteProcessMemory(GetCurrentProcess(), reinterpret_cast<LPVOID>(address), &value, sizeof value, &put) &&
         put == sizeof value;
}

// The local player's FSBActor through the world's actor manager, as fight's vitals() finds her, with its player flag
// set; 0 when the game holds none (the title, a load). read(address, out, n) as the worker's rpm: the stats the revive
// keeps its floor in are at kMinimumHp, her life state at kLife.
template <class Read> uint64_t local_fsb_address(uint64_t base, Read &&read) {
  uint64_t world = 0, manager = 0, fsb = 0;
  uint8_t slot[fight::kLocalIndex + 4 - fight::kActorArray], player = 0; // The actor array, its count and the index.
  if (!read(base + (game::kGlobals + fight::kWorldAt - game::kImageBase), &world, sizeof world) ||
      !game::plausible(world) || !read(world + fight::kManager, &manager, sizeof manager) ||
      !game::plausible(manager) || !read(manager + fight::kActorArray, slot, sizeof slot))
    return 0;
  const uint64_t array = game::get<uint64_t>(slot, 0);
  const int32_t count = game::get<int32_t>(slot, fight::kActorCount - fight::kActorArray),
                index = game::get<int32_t>(slot, fight::kLocalIndex - fight::kActorArray);
  if (index < 0 || index >= count || !game::plausible(array) || !read(array + 8 * uint64_t(index), &fsb, sizeof fsb) ||
      !game::plausible(fsb) || !read(fsb + fight::kPlayer, &player, sizeof player) || !player)
    return 0;
  return fsb;
}

namespace {
// Death and revive: our side, her last SBV line with the place it carried, and the line for the status.
revive::Local revive_local;
revive::Partner revive_partner;
uint64_t revive_line_at = 0; // When her last state line came (GetTickCount64); none this session at 0.
float revive_her_at[3] = {};
uint64_t revive_bad_lines = 0;
bool revive_hold = false; // While revive=on in session/group.lua's words: revive hold on at load and each change.
char revive_status_line[160] = "revive=off";
constexpr uint64_t kPartnerFreshMs = 5000; // Two and a half state intervals: older is no partner at all.

// Her place, and how far it is from ours in cm (revive/core.h's kReviveCm decides a revive); -1 when either is unread.
float revive_distance(const revive::Mine &mine, bool present) {
  if (!present)
    return -1;
  return std::sqrt((revive_her_at[0] - mine.at[0]) * (revive_her_at[0] - mine.at[0]) +
                   (revive_her_at[1] - mine.at[1]) * (revive_her_at[1] - mine.at[1]) +
                   (revive_her_at[2] - mine.at[2]) * (revive_her_at[2] - mine.at[2]));
}
} // namespace

// Her SBV line (revive/core.h): her state and her EVE's place, from a handshaken peer only (peer_receive: a loopback or
// a replay never feeds this, being our own line or an old one).
void revive_receive(const uint8_t *data, size_t size, uint64_t now_ms) {
  revive::State state = revive::State::alive;
  bool used = false;
  float at[3] = {};
  if (!revive::parse_line(data, size, state, used, at)) {
    ++revive_bad_lines;
    return;
  }
  revive_line_at = now_ms;
  revive_partner.state = state;
  revive_partner.present = true;
  std::memcpy(revive_her_at, at, sizeof at);
}

// The friend's revive is the game's setting (session/group.lua): the floor goes on with revive=on and comes off with
// revive=off, giving back the game's own MinimumHP.
std::string ask_revive_hold(bool on) {
  revive_hold = on;
  if (!on) {
    revive::Once once;
    revive_local.session(false, once); // The floor comes off now, not at the next pass.
    revive_partner.present = false;
    std::snprintf(revive_status_line, sizeof revive_status_line, "revive=off");
  }
  return on ? "revive hold on" : "revive hold off";
}

bool revive_pass(uint64_t now_ms, bool linked, bool (*send)(const uint8_t *, size_t, bool)) {
  revive::Once once;
  if (!revive_hold || !pinned || blocked) {
    revive_local.session(false, once); // Nothing is written: the game is gone or off.
    return false;
  }
  revive::Mine mine;
  if (const uint64_t fsb = local_fsb_address(base, rpm); fsb) {
    float stats[3] = {}; // HP, MaxHP and MinimumHP, in stat order.
    mine.fsb = fsb;
    mine.ok = rpm(fsb + fight::kStatBase + 4, stats, sizeof stats) && rpm(fsb + fight::kMinimumHp, &mine.min_hp, 4) &&
              rpm(fsb + fight::kLife, &mine.life, sizeof mine.life) &&
              rpm(fsb + fight::kLocation, mine.at, sizeof mine.at);
    mine.hp = stats[0], mine.max_hp = stats[1];
    for (const float x : {mine.hp, mine.max_hp, mine.min_hp, mine.at[0], mine.at[1], mine.at[2]})
      if (!std::isfinite(x))
        mine.ok = false;
  }
  if (linked && revive_partner.present && now_ms - revive_line_at > kPartnerFreshMs)
    revive_partner.present = false; // She went quiet: no revive from a line from before.
  if (!linked)
    revive_partner.present = false;
  revive_partner.distance_cm = revive_distance(mine, revive_partner.present);
  revive_local.session(linked, once);
  if (linked)
    revive_local.step(mine, revive_partner, now_ms, once);
  if (once.floor && mine.ok)
    wpm_float(mine.fsb + fight::kMinimumHp, once.floor_value);
  if (once.hp && mine.ok)
    wpm_float(mine.fsb + fight::kStatBase + 4, once.hp_value);
  if (once.send && linked && send) {
    const std::string line =
        revive::line(revive_local.rules().state(), revive_local.rules().used(), mine.ok ? mine.at : nullptr);
    send(reinterpret_cast<const uint8_t *>(line.data()), line.size(), false);
  }
  if (once.send && once.why[0])
    say(std::string("revive: ") + once.why + " (" + revive::name(revive_local.rules().state()) + ")");
  std::snprintf(revive_status_line, sizeof revive_status_line, "revive=%s used=%d partner=%s dist=%d hold=%d",
                revive::name(revive_local.rules().state()), revive_local.rules().used() ? 1 : 0,
                revive_partner.present ? revive::name(revive_partner.state) : "none",
                int(revive_partner.distance_cm), revive_local.armed() ? 1 : 0);
  return linked;
}

// coop-status.txt's revive part: "revive=<alive|down|spectating|dead> used=<0|1> partner=<state|none> dist=<cm>
// hold=<0|1>", or revive=off before the first pass. It rides the engine line, where core/link.lua finds it.
std::string revive_status() { return revive_status_line; }

} // namespace coop::pose
