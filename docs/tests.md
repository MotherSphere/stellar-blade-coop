# Tests

The toolchain the tests need is in [Building](building.md#toolchain).

The tests run on the build machine, without the game. `tools/install.py` runs them all before every build. To run one
by hand, from the repository root:

```
lua5.4 tests/lua/partner/puppet_test.lua
python3 tests/tools/save_guard_test.py
mkdir -p build/host
c++ -std=c++17 -Wall -Wextra -Werror -I native/src tests/native/pose/codec_test.cpp -o build/host/pose_codec_test
build/host/pose_codec_test
```

## Lua tests

The Lua tests (`bike/`: `model`, `ride`; `core/`: `actors_of`, `class_at`, `keybind`, `link`, `pak_gate`, `settings_file`, `ue4ss_settings`,
`unreal`; `cut/`: `chainspin`, `devmenu`, `emote`, `enemy`, `flight`, `gardener`, `glide`, `leviathan`, `lines`, `lion`,
`mailbox`, `scene`, `tendril`, `wear`; `main/`: `bike`, `boot`, `fight`, `fight_notices`, `guide`, `idle`, `input`, `match`,
`menu`, `quests`, `sbo`, `session_ui`, `settings`, `story`, `world`; `matrix13/quest/`: `on_time`, `zone_talks`;
`matrix13/talks/`: `zones`; `matrix13/world/`: `boss`, `breakables`, `drone`, `fans`, `mila`, `move`, `travel`;
`nightop/`: `board`, `challenges`, `guard_text`, `probe`, `recruiter`, `recruiter_text`, `roxanne`, `run`, `shop`,
`waves`; `partner/`: `capture`, `ghosts`, `hud`, `puppet`, `sentinel`; `race/`: `doro`, `drive`, `drive_model`, `model`,
`run`; `session/`: `arrival`, `booth`, `chat`, `group`, `halls_rows`, `join`, `saves`, `sbo`, `travel`; `story/`:
`snapshot`, `subtitles`; `ui/`: `guide`, `kit`, `lobby`, `lobby_model`, `model`, `notice`, `region_tabs`, `text`) run
the scripts, with fake UE4SS objects for those that call the engine. In the capture test, any write to the fake EVE
fails the test. The `main/` tests load
`main/fixture.lua` first, with UE4SS stubbed for `main.lua`.

- `bike/model_test` rides `bike/model.lua` on flat ground with Eve On Wheels' default values: 90% of the top speed
  after 3.9 s, a real top of about 2252 cm/s, 15.8 m of braking from the top, reverse after 0.3 s at a stop, the yaw
  rate and lean at full lock at five speeds, the drift's 42-degree slip cap, a wall, the air, a ramp launch only after
  0.12 s of climb, the pitch, root motion holding the state and the values' bounds;
- `bike/ride_test` covers `bike/ride.lua` over a fake EVE and native part: the preload asked once and released at
  `bike=off`, the part made once (at the seat, hidden) or found again after a reload, every mount refusal with its
  reason and nothing written, the mount's order and the dismount backward, the lean, the riding pose played again or
  ending the ride, the 250 ms checks, `coop-bike.txt` and its restore, `coop bike status` and `tune`, the Doro look
  refused while she rides;
- `core/link_test` also covers the status's `uidev=`, `me=` and `world=` lines and the `owner=`, `room=` and `hall=`
  fields of a match lobby's `link=` line, each read as nil without it (`me=` also when the name is empty) and never
  from a player's name; the `shared_world` setting; `bike` and `bike_key` (an older file whose keys hold F3 gets no
  bike key);
- `core/pak_gate_test` finds the hall lobby pak `zSBO_Lobby` in `~mods`, else `LogicMods`, over fake files, checks its
  version (the `.utoc` size and the `.ucas` size from the `.utoc`'s compression blocks, joined by `_`) and that each
  read is bounded,
  and refuses a missing game folder, `.utoc`, `.pak` or `.ucas`, a map or folder missing from the directory index, and a
  `.utoc` whose header does not read as one;
- `main/fight_test` also covers `coop fight pilot` (its `test target` and boss tests included),
  `coop fight spawn probe`, the `spawn_filter` setting with the `filter` word it adds, and the `same_place`, `aggro`,
  `same_spawns`, `enemy_extra`, `bosses` and `boss_hp_scale` settings, whose rows `main/menu_test` covers with the
  `shared_quests` and `shared_world` rows, and `coop pvp` (its words, the `pvp_spike` and `shared_enemies` refusals, status, and
  `pvp_spike=off` ending an earlier load's PvP test at a reload);
- `main/fight_notices_test` covers the same place and same spawns notices in both languages;
- `main/quests_test` covers `coop quests` with the `shared_quests` and `quest_deny` settings and the shared quests'
  notices;
- `main/bike_test` covers the bike through `main.lua` with a fake `bike/ride.lua`: the load line, what the ride gets
  (its asks, `coop-bike.txt`, the driving, the settings, SBO's busy reasons with coop fly and our open screens),
  `coop bike` and its words, F3 and the pad's D-pad Right hold with a refusal on screen, the hold ignored with its
  reason logged at the title, with one of our screens open or with the game paused, the restore, the frame and the
  250 ms pass with an end said on screen, the Options rows, `coop off`; `riding()` as `coop emote`, the race and the
  hall seats read it;
- `main/world_test` covers `coop world` (its words, on and off whatever `shared_world` says, status), the start once a
  load with `shared_world=on`, the end at a reload with `shared_world=off`, and the shared world's two notices;
- `main/idle_test` counts the FindAllOf and StaticFindObject calls of main.lua's two loops over one idle minute, each
  case from a fresh Lua load: 4 and 5 in a world with the UI up, 0 and 2 at the title, all in the first second;
- `main/input_test` covers the controller's events from a fake `coop_pad` (routed to the menu, the co-op saves' question
  and the two boxes, never to the host's question; LB and RB taken and doing nothing there; at most 8 a frame; an
  older DLL without it), the mouse in the menu and the focus watchdog's reset, the Lua frame time line with its
  longest frame and 250 ms pass, their counts over 16 ms and over 50 ms, and the longest call of five modules, and the
  gap lines (a frame over 100 ms after the last, with the 250 ms pass in the gap or none, at most 200 a minute);
- `main/match_test` covers `coop match` (search, create, cancel, end, join with a code, leave), search and create with
  the SBO lobby's room and hall words, `coop mute` and `coop unmute`, and their usage line;
- `main/sbo_test` covers `coop sbo` and the SBO lobby's wiring (the arm at the recruiter, the tick, the title's
  put-back, coop off), the recruiter's auto spawn pass every 250 ms on any save, and the ghost's collision kept off
  during a session; then the lobby's input routing (menu_key, the pad's View, LB and RB, the keys with C's tabs on
  QWERTY and AZERTY, the mouse), the hall seats (menu_key and View held 1 s stand EVE up while she sits, sit her near a
  seat SB's chairs left to menu_key, else open B; the hint says Sit or Stand up, and hides while B is open; a seat read
  that raises is logged once and the rest of the 250 ms pass runs), the engine calls behind SB's chairs (the class found
  in memory or loaded once, with LoadAsset's own error when it does not load, the deferred spawn in EVE's world with
  AlwaysSpawn, EnvActorName set before FinishSpawningActor, each part hidden with its collision off, the actor destroyed
  when a step raises, and the zone and row SB bound it to), its view and what its rows ask for (Search with the SBO
  lobby's room and hall words, Private with the map picked on the settings screen, which is not written to
  `coop-settings.txt`), the countdown feed, the start line, the focus watchdog and the `hud hide` requests (`off` at the
  first pass after a load, then `on` and `off` once each as the screens open and close, and one that cannot be written
  logged once and asked again; `main/fixture.lua` keeps them apart from the other requests); last, the arrival's hold:
  after a lobby warp, ClientRestart's hook puts SB's black up at the next pass (`LoadingScreenFadeAuto` with a 10 s
  lifetime, 0.5 s fades and tag 5) and veils the kit; `hud hide on` is asked under it from the arrival on, passes before
  the lift; the menu camera takes the view while B waits, and once nothing is missing `loading lift` is asked, the veil
  goes and B opens in that pass with SB's HUD still hidden; a Lua load under an earlier load's hold asks `loading lift`
  once, at its first pass in the lobby world and not before, and none when that pass also puts up its own black (one
  fade); without the hook, one log line;
- `nightop/recruiter_test` also covers the auto spawn at each Xion load (waits while the spawn point is not loaded or
  EVE is too far, one spawn a load, a guard kept after a Lua reload, none after `coop recruiter off`) and the arm call
  after `RECRUITER=yes`;
- `ui/kit_test` covers the veil (the root built and kept collapsed, the look warmed in one 250 ms pass, shown again at
  once, and a hidden world's root left collapsed), the menu's mouse cursor, the focus put back after a click, the focus
  watchdog and the focus line
  it logs as it fires, text shadows and wrap, fixed groups, SB parts and the keyboard layout from the game's device. It
  also checks that a root built while its look warms holds each texture it wanted once warmed, so a GC before the next
  build frees none of them;
- `ui/lobby_test` covers the lobby menu and settings on fake SB parts: layout, rows, focus looks, the leave question,
  the countdown, the kit drawing that stands in for a part the game cannot make (row labels, settings items, the
  leave question with Yes and No, the countdown's seconds), the lines logged as the screens open and close and the
  question is asked and answered, the Map row of a Private match (left and right, the pick shown by its name), and
  that no part is ever focused, clicked through or sent a call outside the allowed list;
- `ui/lobby_model_test` covers the lobby menu's rows, actions, status and members by state, the settings rows (the
  Map row only with no lobby open and the hall lobbies in use) and the countdown's resync;
- `ui/text_test` checks each language's notices against the feed's 200-byte line, the SBO lobby's notices included,
  and the lobby menu's rows, settings, values and status within their columns, and the hall seats' Sit and Stand up
  hint within the booth hint's width;
- `session/arrival_test` covers the hold at a lobby arrival: nothing without a lobby warp or before its new
  controller; SB's black up and the kit veiled at the next pass; held while anything is missing, then lifted once with
  one line; the 8 s cap, which lifts whatever is missing and names it, also when the missing items cannot be read; a
  second warp under the hold (a guest following her host), which keeps the black and counts the cap from its own
  controller; a disarm (a refused warp, coop off); the 60 s arm cap; a black that does not show; and a lift the native
  part cannot take, which still removes the veil;
- `session/chat_test` covers the Thai leading vowels at a row's end;
- `session/halls_rows_test` checks the hall lobbies' 181 rows (5 worlds, 5 zones, 171 seats) against
  `lion/halls_rows.h` and `session/sbo_maps.lua`, then the title's ask: none without the lobby pak, once with it on the
  co-op save files, read back; a refusal, a fault or rows that read back wrong keep the lobby in Xion with one log line,
  also after a Lua reload, and a shut gate's refusal is asked again;
- `session/sbo_test` covers the lobby's spots, fence, row sets, notices and entry checks, and the entry and return from
  the status line, a double Join, a late arrival, coop off while warping and a Lua load in the middle of an entry, and a
  Join that enters again after SB's own reload cut an entry short (record open or warping); then the room shown, the
  spots and their re-place, the fence, hop and back, and a Lua reload in the lobby, with the log lines for the room, for
  where EVE stands one pass after a teleport and for each fence catch. It also covers an arrival whose status shows
  `arrivals=` one line before `record=arrived`, a room read that raises, and a new session that drops the last session's
  round order. Then the menu camera, its sweep after a reload, the view and sequence tools (`coop sbo view`, `view set`,
  `seq`). Last, the hall lobbies: Xion and one log line when the game folder, the lobby pak or the hall rows are missing
  (refused rows are logged by `halls_rows` only), a hall drawn at random with no Xion row edited, a hall zone that is
  not a name yet, and in a hall its spots' Z, its fence, its menu camera and FOV, no training room, no `seq`, its status
  word, hop and back, and a Lua reload that takes the hall from the client zone. Then a match request's room and hall
  words, and the match lobby's map: a guest whose lobby is on another hall warps there once per arrival and joined lobby
  (a refused warp is not asked again, and a lobby the regroup moves her to is followed), a lobby on a map she lacks, on
  Xion while she uses the halls, or of another pak version is left with its notice, the same lobby joined again is left
  again, and a host or a co-op lobby makes no warp. Last, a Private match: asked at once on the hall EVE stands in, else
  after a warp to the picked hall at her arrival there; Random draws a hall; a refused warp creates nothing, nor does a
  warp that lands in another lobby (its line is logged) or one whose session closes before the arrival; Private again
  while the warp runs is refused, and asked once that session has closed; a warp the Lua side refuses at once (the
  hall's zone not a name in this game run) returns its why, asks nothing, and leaves the next Private free to warp;
  without the halls the request names Xion. Last, the hall seats. SB's chair per kind: its place puts EVE's seated spot
  on the seat with her facing the seat's yaw (Hotel's seat 1 checked by number). A hall arrival spawns one chair per
  seat with a row, in the arrival's pass on the budget or one a pass past it, with the kind's class looked up once, the
  seat's row, its place and the parts to hide; a spawn that raises is logged and the rest go on; a class that does not
  load costs one lookup and leaves its kind without chairs; the camp seats get none; Xion and the arena get none; a warp
  stops the spread, and each new arrival spawns again; a Lua load in a hall spawns none, reads the binds of the earlier
  load's chairs and leaves to menu_key each seat none of them is bound to (every seat when that read raises, logged).
  The bind check runs once, 1 s after the last spawn and with SB's loader at 3 or 4: one line with the counts and the
  seats left to menu_key (no chair, one SB did not bind, or one whose bind read raised: the first such error is logged
  with its seat), whose sit loops are looked up once a kind, a look-up that raises listed with its error. SB's
  interaction on EVE is logged as it starts, with the seat nearest her, and as it ends, and `busy()` says it runs. Then
  the menu_key sit on those seats: the nearest within 1.5 m, none in Xion, while EVE sits, while SB's interaction runs
  on her (an unbound seat 70 cm from the chair SB seats her on), before the bind check, on a bound seat, or at a low
  bench the generator left out; a sit turns her collision off, teleports her to the seat at her standing height, holds
  her movement and plays the seat's loop, in that order; she stands up when the loop ends, on `stand()` and at coop off,
  with the teleport to the approach point while her collision is still off, then her collision and walking back, also
  when the teleport raises, and the next pass logs where she stands and how far from the approach point; a refused
  teleport or loop is undone the same way; an arrival forgets the seat, and so does a warp whose new EVE (or no EVE)
  ends the loop before the arrival, with no call to that EVE, even when the game puts the new EVE at the old one's
  address (the seat keeps the arrival count she sat at); a Lua load in a hall that finds her collision off stands her up
  at the approach point of the nearest seat, and in Xion changes nothing. Last, the arrival's hold: the entry's warp, a
  guest's follow, a Private match's warp and `coop sbo back` arm it, the hop to an arena does not; a warp the native
  part ends without an arrival, SB's own reload and coop off disarm it; `unready()` lists the arrival, EVE's spot, a
  hall's bind check and the menu camera until each is done (no chairs in Xion); under the hold the chairs spawn on the
  100 ms budget;
- `story/snapshot_test` holds the in-game story dump to `tests/tools/story_case.txt` and its floats to
  `tests/tools/float_repr.txt`, the files `story_lines_test.py` checks the save side against.

## C++ tests

The C++ tests cover the platform-free headers in `native/src`.

### Link

- `link_protocol_test`: the text protocol, with a fuzz loop, the requests from Lua (`coop fight` with its `place`,
  `aggro-host`, `bosses <boss %>`, `spawns`, `extra <n>` and `filter` words and its `pilot` requests, `test target` and
  the boss tests included; `coop fight pvp` and `pvp off`; `lion rows`, `gardener rows`, `tendril rows`, `bolt rows`,
  `mxiii rows`, `shop rows` and `signal rows` with their 25 table words and bad addresses, the longest of them 813
  bytes; `fly` and `slowmo` on or off; `anim play` with its id, path and `once`, `loop` or `ride`, and `anim stop`;
  `bike load <clip>`, `bike free`, `bike gate on` and `bike gate off`, a mesh, a package path or a mod's clip refused;
  `shortcut list` and `shortcut load <map> <1-4>`; `hud hide on` and `hud hide off`; `loading lift`; `nightshop`,
  `roxanne`, `lily`,
  `guardtext` and the 8 `signal` words, in `quest/own.h`'s order; the `sbo` requests (`on`, `arm`, `enter`, `warp`,
  `abort`, `leave`, `seq`) and their refusals),
  Night Operation's night line (its round trip, its refusals and a fuzz seed), and the join
  codes (both real lobby ids, loose typing, malformed codes, and the share of one-character typos the check turns away),
  the match modes (`find_mode`), `match search` and `match create` with their room and hall words (each refused when
  missing, extra, too long or not an alias word), `match cancel` and `match end`, `mute` and `unmute`,
  the match lines (start, count, end) with their bounds, and protocol 21 refusing a protocol-20 lobby and line;
- `link_core_test`: the link against the shared fake Steam, and two links through it with the handshake both ways,
  channel 1 and channel 2 with their checks, the photo line, the chat and vitals lines, Night Operation's night line,
  joining with a code, and the host's approval of a player who is not a Steam friend (let in, refused, no answer,
  removed, a flood while waiting), with relay only set on both games before their first session with each other;
- `link_pose_cap_test`: the adaptive pose rate (`PoseCap` in `link/core.h`), one reading a second: a calm link and
  a lone bad reading never step; two readings in a row over the line (queue time or pending bytes) step down 60, 30,
  20, to the first cap under the player's `send_rate`, never below 20; 10 calm readings step up one cap; a step up
  undone within its wait doubles the wait up to 80 s, and one that holds brings it back to 10 s;
- `link_match_test`: the fake Steam shared with `link_core_test` (`tests/native/link/fake_steam.h`, eight clients and
  the `Mesh` harness that runs several links in one test): the matchmaking exports named when missing, two co-op links
  through the harness, callback 506's log line, `me=` with our name after the first status line and no `owner=` in a
  co-op lobby, eight links in one match lobby (no approval, every pair linked, the owner's SteamID as `owner=` on the
  owner's and a guest's `link=` line, ghost slots 0 to 6 and a freed slot taken again, `friend=` from slot 0, the
  slot-0 member leaving a lobby of three, whose `friend=` line goes while the third member stays linked and still gets
  our chat line, no `mate=` line, the mods every member shares), a
  co-op lobby that stays at two, a lobby of an unknown mode left, each channel-1 message, channel-2 line and chat line
  handed on with its sender, a channel-2 line to one member, `lines_from`, quick match (the exact filters and their
  order with the relay-only setting, a lobby created when none is found with its member limit and data, seven more
  searchers joining it, another version's lobby and a code match lobby never found, two searchers in one pass each
  hosting a lobby of one, merged into the lower lobby id when the lone host searches again 5 s later with her lobby's
  hall, the mover then reading the lower lobby's room, which the next searcher joins, one search at a time, a full
  first result skipped, a lobby created when every result fails, an unknown mode, a search refused in a lobby, a
  cancelled search), a private match lobby by code (Invisible, no `sbo_state`, its code, a stranger joining with no
  approval), the room and hall a created lobby carries and its `link=` line, a search that finds only lobbies of its
  own hall, a member reading both each pass and dropping a word `alias_word` refuses, the ICE setting given back in a
  co-op lobby, the host's
  countdown (none alone, 10 s from two members with each member told, a member joining while it runs told the time
  left, 5 s once eight, stopped under the minimum, checked again at 0), the start (the lobby closed, `sbo_state` and
  `sbo_map`, one start line with the same seed and member order everywhere), `match end` and the next round's countdown
  and seed, the lines a guest refuses (from a member who is not the owner, a start without her), a code join after the
  start told the game is closed, a host left alone in a round in play, who does not search again, the host leaving
  (the lobby handed over before a menu leave, a crash, a silent owner, an owner change during the countdown: the round
  ends everywhere and the new owner reopens the lobby and counts down; a silent owner's countdown stopped on each guest
  once the owner is lost; a guest who drops out of a match lobby leaves without a rejoin), the stranger rules of a match
  lobby (a reject from the owner only, a mismatched hello refused by
  the owner who keeps the lobby and ignored by a guest, no photo or cutscene pause, gift, race, follow, night or shared
  quest line either way), floods (no pong past 4 pings a second; a member over channel 0's 128 lines a second for 5 s
  refused by the owner and by a guest, who both stay, her session closed and no reject every 10 s; 200 lines at once
  not refused; pose data before any hello, over channel 1's limit for 5 s, refused; a guest leaving an owner who
  floods), the owner's round lines on a guest (a count line logged only when it moves her countdown, one notice for
  a start without her, past 8 a second dropped and logged once), the per-player chat mute kept for the run, per-peer
  pose caps (30 a second for a member of a match lobby, one peer's cap stepping down alone, one second of poses
  reaching peers at 20, 30 and 60 a second, tables always sent) and the 60 s line of passes and full receive batches;

### Poses

- `pose_engine_test`: the pose path against fake memory;
- `pose_codec_test`: the codec's round trips, the deltas against a keyframe, a decoder fuzz and a 60 a second stream
  with every second delta dropped, which decodes whole;
- `pose_delta_gain_test`: what the sender's delta tolerance (`kTolerance` in `pose/codec.h`) saves. With no
  argument, as `tools/install.py` runs it, it encodes two synthetic recordings (idle and running) made by the real
  sender with no tolerance and with it, checks that the tolerance saves bytes on both and prints keyframes, deltas,
  their mean sizes and KiB/s for each. `build/host/pose_delta_gain_test path/to/coop-record.bin` measures a recording
  of the current protocol instead;
- `pose_table_test`: the component table and the display file, with a parser fuzz, and the per-slot file names
  (`slot_file`);
- `pose_resend_test`: our component table's resends (`TableResend` in `pose/table.h`) on a worker passing every
  50 ms: at once to a new friend, then 5, 10, 20, 40 and 60 s apart, every 60 s from then on; a change brings the
  next one 5 s after it and starts the doubling over; a sign her side lost our table brings it within 5 s, and a
  flood of them sends one each 5 s at most;
- `pose_record_test`: the recording's reader, with a fuzz, and its replay, with same-place enemies' `SBE` and show
  lines re-stamped on the poses' clock;
- `pose_stream_test`: the loopback pipeline in simulated time, and the playback of a match lobby member who gets every
  2nd or 3rd pose of a 60 a second stream (cap 30 or 20): with 100 ms of lag she is drawn 150 or 175 ms back;
- `pose_inbox_test`: the game thread's pose inbox (`kInbox` in `pose/core.h`) in a full match lobby, 7 members
  sending 60 or 30 poses a second: one game-thread stall of 102, 198, 291 or 361 ms (the stalls of steady play
  in the 2026-11-12 log) drops no pose and leaves no delta without its keyframe;
- `pose_gap_test`: the native tick's gap line (`gap_line` in `pose/core.h`) from fixed values: the UTC time of day out
  of a FILETIME (the last 100 ns of a day included), the gap in whole ms, a frame past 32 bits, the tick before it,
  and the `vkd3d-proton.cache.write` growth, left out when there is no such file;

### Saves

- `save_watch_test`: the save watcher;
- `save_slot_test`: the slot line, the marker, the save file name's lookup in the game's constant table, its
  switch and the read-only probe, against fake memory, and the title check, which also refuses while SB reloads the
  save (client +0x2f9c) or that flag cannot be read;
- `save_twins_test`: the co-op save copies on a temporary folder: the game's save check, the name check on every
  write (the SBO session record `StellarCoopSBO0N.bin` included), the manifest, the backup before the first copy,
  torn reads and failed writes, the requests and the switch against a fake game (refused during SB's own reload too),
  the plant of a built save as one co-op copy with its mark, and the export's refusal of a planted copy;
- `save_rotation_test`: the per-save copies' folder: the names it accepts (`<UTC>.sav`, `-pre.sav`, `-session.sav`,
  `-replaced.sav`, a `-<n>` after a clash) and every other name refused, a free name on a clash, the drop that keeps
  the 10 newest, spares the open session's two copies, never lists a `-replaced.sav` copy and never lists another
  file, the save queue's fall to 0, a save seen as rewritten by its size or write time, and the copy a restore keeps
  of the file it replaces as `-replaced.sav` (no name when the write fails or reads back different);
- `save_sbo_record_test`: the SBO session record's text and its refusals (another version, an unknown or repeated
  key, a slot outside 0 to 4, an unknown state, a copy name with a folder in it, a line cut short, over 4096 bytes,
  each required key left out, a `pre` or `session` that is not a rotation name), the sidecar's name,
  `NewGameCreateTime` read from a built save and C1's test that it matches the record's, and the write against a fake
  folder: the old sidecar backed up first, then put, and a read-back that differs refused; a missing sidecar reads as a
  closed record; the rotation copy against a fake folder (the oldest past 10 removed only after the copy reads back
  and the sidecar reads, the open record's session copy spared) and the restore (the replaced file kept first, no put
  without it);
- `save_shortcut_test`: `coop shortcut`'s paths and its read of built GVAS bytes (the engine branch, `MapName`,
  `CampAlias` and `DateTime` within their maps, an EVAS header stripped, short and bad bytes), its copies, lines and
  summary;
- `save_shortcut_load_test`: `coop shortcut load`'s cleaning on built GVAS bytes (`SBAchievement` dropped, six
  gears out of `Inventory` and `ItemOtaineSet` with every size fixed, items with no row kept, a gear named anywhere
  else refused, the EVAS wrap and its CRC, the pin, cut bytes refused), then the 15 developer saves themselves when
  the machine holds the research copies under `~/.claude/project-notes/stellar-blade-minecraft/runtime/2026-10-26/`
  (skipped elsewhere): each cleaned and checked, the file without `SBAchievement` byte for byte, with no achievement
  name or gear left and no item missing from the `ItemTable` dump but the seven known ones;

### Night Operation

- `nightop_probe_test`: the Night Operation poller's reads, lines and verdict against a fake image;
- `nightop_roxanne_test`: Roxanne's and Lily's choice lists in SB's select cache (`nightop/roxanne.h`) against fake
  memory laid out like the pinned build: on (our six rows in a GMalloc array, the pointer written before the count,
  her old array never written), off (her pointer, count and max back), a second on, an element array moved by a
  rehash, an entry the game rebuilt, the refusals (no world, no holder, her list absent or of another shape, no
  memory) and the `roxanne=` line; Lily's eight rows taken in the cache's own order behind the borrowed row, a row
  twice, one of another list or one missing refused, and the `lily=` line;
- `nightop_guard_text_test`: the Xion guard's 12 text keys and the 23 cultures, a `guardtext` request's culture and
  seven lines into UTF-16 (Korean, the French no-break space, a character outside the BMP) and each refusal, what the
  game thread writes before and after coop off, and the `guardtext=` line;
- `nightop_shop_ui_test`: the Night Operation shop screen's guard (`nightop/shop_ui.h`: a client and its UI manager
  always, in game and playing for an open only), its answer word's round trip, the `nightshop=` line and the log
  lines;

### Table rows

- `lion_rows_test`: the Lion's, the Gardener's, the Tendril's, the Shock Bolt's, Matrix XIII's and the Night Operation
  shop's rows against fake memory laid out like the pinned build:
  - the recipes:
    - unique names and IDs across the batches, every patch inside its struct, the steps, skills, commands, stances,
      moves and target filters pointing at the new rows, the CharacterTable rows last with the link flag Common and the
      phase-2 stance, no value naming a Behemoth row or asset but the sound set;
    - the Gardener's ToxicBeam steps, skills, stance at speed 0 and CharacterTable rows;
    - the Tendril's skills on their run-time Shows, its Hit steps on its own areas, its stance, dead and CharacterTable
      rows;
    - the Shock Bolt's 4 rows;
    - Matrix XIII's camp, the env-spawn row that leads the travel there (the camp base) and the 6 camp objects, each
      naming the camp and spawning its blueprint at the spawn point of its own name, the third zone's camp with no coin
      and its row in `Zone_DLC02_30`, then the 5 trigger rows patched in place, in a table with no parsed arrays;
    - the shop's Beta Seed, shop items and shops;
  - a whole run of each batch:
    - each row built from its template with the game's lazy-init flag and parsed arrays reset, its ID and patches of
      every kind, AddRow given the new name;
    - the Gardener's reading only the tables its rows go into, a ProjectileTable of another row size stopping the Shock
      Bolt's batch, not the Lion's, and Matrix XIII's 10 rows from patches of their own in the two zone tables and its 5
      shipped trigger rows copied back over themselves, never added, a ZoneEnvSpawnTable or ZoneTriggerTable of another
      row size, a taken camp ID, a missing trigger row or one its ID does not name stopping that batch alone, a
      ShopTable of another row size stopping the shop's batch, not the Lion's;
    - Lily's signal's 24 quest rows (8 filters, 7 tasks, 7 groups, the two quest rows last of them) with their task
      containers and filter list built in the pool and the borrowed choice row patched in place with no ID check, a
      TheaterSelectDataTable of another row size or a taken quest ID stopping it;
    - the hall lobbies' 5 world rows, then 5 zone rows each naming its world row, then 171 seat rows each naming
      itself and its hall's zone, a taken zone ID stopping it after the worlds, a taken seat ID at that seat and a
      ZoneTable of another row size before any row;
  - the refusals that call no AddRow (a missing template, a taken ID or name, a wrong vtable, AddRow slot or row size);
  - a later run skipping the rows already in, FName's number split, the read-back through the game's lookups by ID, the
    answer word, the `lion=`, `gardener=`, `tendril=`, `bolt=`, `mxiii=`, `shop=` and `signal=` status lines and the log
    lines;
- `lion_shock_test`: the Shock Bolt's two lists against fake memory: both gun stances given the two fire commands
  (through the game's grow or inside the capacity), the const ammo list and the slot manager's list given
  `Bullet_Shock`, a second run writing nothing, no slot manager yet, the key found down its hash chain, each refusal
  writing nothing, an allocation that fails, the answer word, the `shock=` line and the log line;

### Shared enemies

- `fight_engine_test`: the shared enemies' side inside the game, the enemies `fight_chars=auto` picks and leaves out,
  the enemies' state map, the two-player scaling, the vitals read, and same-place enemies' freeze (BlockAI put back
  after the game's own dispel, freeze-lost after 5 tries in any 10 s, none in the turn we start a crowd control, taken
  off before a kill and on every way out, none of ours on a copy the game froze first until the game's freeze ends by
  its dispel or a timed row running out, a refused dispel tried again and its copy not taken later for one the game
  froze, a floor that keeps a killed copy alive frozen again from the next turn, a copy the game thread would not drive
  let go the same way) with the pair table for the game thread, the rows it captures (only those the side owns and does
  not draw), the rows it drives (only those it draws) and how it reads the table (fresh for 1 s after the job published
  it and never once the engine is latched; the Shows told so far are told again only after a new session, a new
  generation or a change of the table's on, not after a stale table), against fake memory.
  - Same place is the host's setting: the guest draws only while the host's last place line says on, and never reads her
    own;
  - `coop fight pilot off` and the pilot's latch stop it on either side (the host then sends place 0), and the worker's
    `pilot=` words say why it does not run (on the guest's side, `host` only once the host's list came, `fight` after
    its off or on line);
  - stage 3b's hand-overs on both sides (the host's rule and its own lines, its freeze and thaw, her answers and
    give-backs with each own-no reason, no hand-over to a side whose copy the game froze first but for her takedown,
    `target` for a take-over her game thread refused, a pair kept from her for 30 s after her own-no about it, the
    table's taken mark only after a hand-over) and in two worlds, where an enemy has no AI copy or two for one hop at
    most;
  - stage 3c's takedowns (her exec lines from the markers, exec 0 after 200 ms without one, the host's hand-over past
    the guards once its copy is kReady and its freeze despite Groggy, the host's own takedown, a BossMonster refused, a
    balance emptied by her claim in the turn of her exec 1, her lethal claim held until her exec 0 or for 6 s, a copy
    frozen on its stream's takedown, `coop fight pilot test exec`) and in two worlds, where her takedown holds the
    host's kill until her exec 0 reaches it;
  - same spawns in two worlds: nothing while the host's `same_spawns` is off or the players stand 200 m apart, then her
    set becomes the host's (keys created where the host's stand and paired, keys the host lacks despawned, save, keep,
    event and other-zone keys left, a Monster outside `fight_chars` never sent, nothing killed), a spawn line of an old
    epoch dropped after the host's zone resets, a drop line ignored for a key paired on her side, nothing done while a
    census's list of keys is partial, and a Save row logged once, with keys that have no row kept out of the 512-row
    cache and rows past it never logged;
  - the two game calls on fake memory (the spawn with the spawn manager, the key, where the host's enemy stands and its
    yaw; the despawn with the job sender, the turn and the GUID), none with no spawn manager, job sender or reg made, no
    despawn while her enemy holds BattleMode or runs a takedown marker (then one once she is done), and no call, line or
    log line after a latch on an unreadable row, and a host enemy of a SaveWithTransform row never sent;
  - the read-only spawn probe (each shared Monster's row told once an epoch, 32 a census at most, nothing sent or
    called);
  - the `fight=` line's `spawns=` field;
  - extra enemies in two worlds with `enemy_extra=2` (two `NewActor` calls for each of the host's four enemies, 2 and
    3 m from it, the same keys made on her side where the host's stand, all twelve paired, one 130 m from both EVEs
    despawned on the host and then by a drop on hers, the rest despawned at the end, hers when the host's off line
    comes, nothing killed), and on the host alone (no extras for a BossMonster, an NPC, a ZoneEvent or Quest spawn or a
    charId not shared, none before the zone is settled or while she stands 200 m away, an extra 105 m from her ghost
    kept, a dying one left and the other despawned when her shared enemies stop, extras off when the tables hold a row
    at the first key, `NewActor` refusing or the reg not made logged once a life, an extra whose GUID cannot be read
    logged as kept, a new session's extras under the next n);
  - the `extra` word reaching the stats line;
  - shared bosses (BossMonsters taken by `fight_chars=auto` only with bosses on, on the guest once the host's bosses
    line came; their MaxHP times `boss_hp_scale` once and back at off; a boss never handed to her; in two worlds with
    same spawns on, a boss both saves hold paired and scaled in both, one only the host's save holds left unpaired, one
    only hers left hers, none created or removed);
  - her boss copies taken out of battle mode (after 10 s of the host's lines with no bstart, a 15 s silence of the
    host's not counted, at the host's down, at her own same place off and at the session's end, a dying one left alone;
    a new copy paired in the turn its pair's old one went keeps its boss start);
  - the `bosses` word through a recording and its replay;
  - and the boss tests of `coop fight pilot test` on the nearest frozen boss copy (SetBattleMode once a copy and no
    BattleMode_5s on boss copies from the next session, a phase line and the threshold's dispel 5 s later, the copy held
    at 1 HP with no claim and the host's HP back after 10 s, or its HP from the start when the test stops early, a
    summon made, frozen and frozen again, then removed as unpaired, or at once when the freeze is refused; one test at a
    time, none left after the session ends);
  - Night Operation's wave monsters, taken like any keyed Monster, and paired by their keys in two worlds, where the
    host's kill reaches her copy only when she took part;
  - and the spawn filter's table in two worlds (her blocked keys published while she filters, refused by a fake hook on
    her reset, nothing published without the filter or on the host's side, a key the host spawns again let through, the
    host's dead on her paired copy blocking its key but not her own lethal hit, the table empty at a new session, at the
    host's off and at the end, and the gate);
  - the PvP test's mode in the worker (a co-op save and a linked friend, never beside the shared fight either way, her
    pvp lines alone reaching the job with her SteamID, its own sent reliable, no restart at a host change, a pause and a
    new session when her link drops and comes back, `coop pvp off`);
- `fight_sync_test`:
  - the shared enemies' channel 2 text (with a fuzz),
  - the host's and the guest's rules (the place line sent after the world and at each change, and held by the guest
    until the host's next world; the aggro, own and own-no lines taken from the right side only; the bosses line after
    the aggro line, held the same way; boss pairs first in the 16 places, a common enemy's place taken by a boss (not
    while its kill or her takedown is under way) and never the other way; the exec line's checks, rate and holds of a
    kill and of a dead, an exec 1 that never restarts a running takedown, a held claim's 6 s cap, a balance emptied by
    her claim in the step of her exec 1, refusals within 2 s counted with no line; same spawns' epoch, have, spawn and
    drop lines refused by Host and Guest, since the engine takes them, and never recorded),
  - the boss table of stage 5 (one row a boss, each row's allowlist sent in a phase line and read back the same, the
    rows two bosses' shared step applies kept apart, the summon rows),
  - the bstart, phase and summon spawn lines with a fuzz,
  - the guest's checks of them (one bstart a copy, taken again by a new copy under the same key or on a repeat after the
    pair forms, phase IDs from that boss's allowlist only, a summon's key, row, charId and owner),
  - the PvP test's pvp line (round trip, and the refusals: d of 0, a sign, a decimal, past 10,000,000, a skill of 0 or
    past INT32_MAX, a seq of 0, a missing or extra field, the old tag),
  - and two fake worlds linked through a delayed, lossy line;
- `spawn_sync_test`: the core of same spawns (stage 4):
  - which rows take part,
  - each side's epoch (a zone change, a reset of the spawn manager, 3 or more keys with a new GUID, two actors of one
    key no change) and its 3 s grace,
  - the host's epoch line (at each change and every 5 s),
  - her rounds and its answers (a key more than 1 km from her held back until she is nearer),
  - the guest's rounds and her checks of each answer (the epoch, the shared zone, her own tables, 1 km, the rates, a
    created key that is no Monster or another charId, removed again within the rates or kept and logged when it cannot
    be found again, a drop of an enemy she fights refused as busy and asked again, the refusals that show the two games
    differ counted apart),
  - a key refused as too far asked again,
  - a created key that died leaving her rounds,
  - extra enemies (their keys and places, which enemies get them, none for a Save or keep row, an Elite or an enemy past
    116 m, once a life, the room left and stage 1's 16 pairs, n going on after a new session, the host's answers and her
    checks for extra keys, `row taken`, a charId none of her Monsters has yet or a `full` refusal asked again,
    `not made` counted as no difference; their keys below the summons' range, and a summon's key never made by same
    spawns),
  - the guest's blocked keys for the spawn filter (a drop she despawned, the host's kill of a paired copy, never an
    extra's key, a spawn line of the host's epoch taking a key off before her spawn, cleared at a new host epoch and by
    `clear()`, kept through her own epoch moves, 240 at most),
  - and two fake worlds through a delayed line until her set is the host's, with an epoch that moves while a round is on
    the way;
- `pilot_test`: the core of same-place enemies (stages 3a to 3c):
  - the SBE message with a fuzz, the gen and owner epoch filters, an enemy's samples drawn on the ghost's own clock
    (150 ms extrapolation cap, warp, hole and 3 m snaps, a velocity of 100 m/s at most), the drawn copy's states with
    the 2 m convergence snap, the capture list's restore order;
  - the show lines with a fuzz and the Show paths they refuse (outside the roots, over 200 characters, a character
    outside `A-Za-z0-9_./`, `..` or an empty segment), their timeline and line ids, the FNamePool decode and compact id
    over fake blocks;
  - the owner's capture against fake memory:
    - each enemy found through the game's two lookups by GUID, its root, flags and animation speed into SBE;
    - the show manager's stages matched by their main actor's weak pointer, a stale one refused, an empty one matched by
      the actor's show interface;
    - only the first player of a stage, a finished one never told;
    - show-set and show-stop;
    - each asset's path decoded once, and again when another asset takes its address and index under another name or
      package;
    - a character pending kill, a failed lookup, a wrong class, no world, no show manager or a logic task in flight;
  - the drawn side's writes against fake memory:
    - each copy found by its GUID every frame and skipped while it is not or while a logic task is in flight, its rows
      then kept for a later frame;
    - its movement component taken out of the game's parallel manager only when it is the game's class with the game's
      own function in slot 0x350, and again when something put it back;
    - the speed override, the root moved through its vtable and Velocity;
    - the drift probe;
    - the Show replayed through the handle API with its hit context (each field at its offset), only on a copy driven
      that frame, show-set and show-stop (also while the copy is not found), a missing asset, a context too far away,
      the oldest replay giving way when eight are held, at most 2 AddShow calls a frame and 60 a second, the lines
      behind waiting in order (late once more than 34 ms past their stamp);
    - a Show the copy started itself less than 1 s before not replayed again, unlike another enemy's, an older one, a
      finished one or one of its own replays;
    - a release;
    - a log line per release, convergence and snap;
    - restore's order on every way back, with Velocity zeroed and the class checked again before the component goes
      back, once after a fault and nothing after it;
    - `coop fight pilot test`'s steps, each copy put back once at a change and driven only from the next frame;
  - stage 3b's owners (the host's rule, its guards and hold, random hand-overs over a delayed link, the 30 s pause after
    an own-no);
  - stage 3c's takedowns (the rule giving a pair to its executor at once, the guest's exec lines, their spacing and the
    200 ms wait before exec 0, a drawn copy following the stream through a takedown) and the take-over (the copy put
    back first, then the game's force target, only on a pair a hand-over brought; its net mode and logic task gates, a
    stale or missing copy, the refusals named for the job's own-no, the latch, `coop fight pilot test target`);
  - and two worlds through a delayed, lossy line (120 ms, plus or minus 30, 2 % lost), where the guest's copies stay
    within 30 cm of the host's enemies at the same host time while they move (an 8 m/s lunge to a dead stop included)
    and 5 cm at rest, the show lines apply in the host's order with no Show held back by those two caps, and restore
    puts every copy back to local, with its CMC back in SB's movement manager and the speed override gone;

### PvP test

- `fight_pvp_test`: the PvP test's bounds: the cap per named move (the victim's attack and critical damage, the move's
  AttackDamageRate, 1.2 and a margin of 2, at most 10,000,000), a sender outside the members, the range, a move with no
  cap, d clamped to its cap and to half the victim's MaxHP a second per attacker, 60 lines a second per attacker, and
  the windows of members who leave and come back;
- `fight_engine_test`, the attacker's side: no stand-in before her ghost is drawn, one `M_DummyA` from `NewActor` at
  her feet plus 97 cm with no spawn key, BlockAI_Infinite, Off_Hud, DisableMonsterWarp and Passive_Immortal in that
  order with itself as caster, its MaxShield set to 0 once with NoDamage passed (its Shield goes with it, with no
  shield break), each drop healed at the next turn and sent naming our EVE's skill (or one seen within 1 s; else
  unnamed), a hit past its HP held at 1 by Immortal and never a death, no move for 3 cm, one for 10 cm and none while
  her ghost is not drawn, a stand-in the map lost made again, three tries 5 s apart when SB refuses BlockAI, and the
  despawn at the end;
- `fight_engine_test`, the victim's side: a MinimumHP floor of 1 on her EVE for the session and off at its end, each
  line through ApplyStat on her EVE with no cause, the HP number and NoDamage not passed, the cap per named move (252
  for LightAttack1_1 with attack 100 and critical damage 1.5), her dodge (state 3) refusing it in the game with the
  state logged, half her MaxHP a second, a stranger, a skill with no row, her ghost 20 m away or not drawn; her own load
  mid-session (a line with no EVE refused and nothing written on the old actor, the floor and the hits on her new EVE);
  and two worlds, where a 60 HP drop of the stand-in in one game takes 60 HP from the other's EVE;

### Other native headers

- `photo_freeze_test`: the synced photo mode's pause against a fake pause set;
- `globals_test`: SB's globals as build 26123051 lays them out, checked at compile time: the block offsets the fight
  engine, the photo freeze, the lion gate and the Night Operation probe read land on the registry, the world, logic
  and the net-mode cache, and every header that names one of these globals by address names the same one;
- `debug_keys_test`: `coop fly`'s and `coop slowmo`'s gates against fake memory laid out like the pinned build: the
  keys' hash, the lookup through inline and allocated buckets and along a chain of collisions, each refusal with no
  write, and the passes (a gate set with its old value kept, set again after the game built its map again, its old
  value back once unwanted, nothing read while neither gate is wanted or ours); the worker's side: no gate wanted off
  a co-op save, slow motion only with no friend linked, the asks cleared by `off`, a Lua load and a refusal, and a
  gate's state logged from the first pass that read its ask, never from an earlier one; the level flight's hold: the
  flight key set again only while the controller's pawn flies with none held, never after a press of the jump key
  in that flight until it ends (a jump key held from before the flight counts only once let go and pressed again);
- `anim_test`: `coop emote`'s native clips: the clip paths that pass, the game's string built from one, the call's
  arguments, the custom animation slot as read, and the track (a play answered with or without an id, the watch on
  our clip, another clip, a cleared slot, a gone EVE and a slot that takes no weight, with paused time left out,
  the stops, the fault, the status word and the log lines), our EVE as the controller's pawn and the check that she
  is still the object played on, over fake memory (no pawn, a pawn of another class, a pending kill, a new serial),
  what each frame does; the bike's `ride` play (a loop forever with foot IK type 2);
- `bike_test`: the bike's native side (`game/bike.h`): the preload path rule, the 55 gated names, the gate over a fake
  action map (each state kept and put back, an absent name back as on, a name SB changed during the ride left as SB set
  it, a name the game never made skipped, a controller gone, a fault), the words packed for the worker and the status
  line, the ride plays' clip lookups and the log lines;
- `items_test`: `coop gift`'s inventory read against a fake image laid out like the pinned build: the FName and
  CityHash64 hashes checked against the game's, a count over two instances and along chains of collisions, an item
  EVE does not carry, no manager, bucket or owner, an instance the manager no longer holds, and hostile memory (a
  chain that loops, an index past the array, a hash size that is no power of two, an unreadable item) ending in
  `unread`, never in a hang;
- `pad_test`: the controller's events for the co-op menu (each press, up and down repeating while held, a D-pad
  diagonal read as up or down and the stick along its main axis, which keeps its pressed axis near 45 degrees, the
  stick's thresholds, View held 1 s, D-pad Right held 1 s for the bike, LB and RB once a press and in event order with
  up's repeat going on, a disconnect, the event queue) and which XInput slots each poll asks;
- `dev_panels_test`: `coop devinfo`'s guard (each read failing alone, refused with its own reason; a close needs
  neither the flow nor the phase), the plan over every mix of open panels and every ask (the other panel closes, the
  one asked opens unless it is open), and the two panels' logic types and names;
- `travel_test`: the follow's fast travel request, its bytes at each offset, each guard refusing with its own reason
  (a respawn in flight included), the call count (three calls in 10 s, a 10 s wait after an accepted call, none after
  a refused one) and the watch over the warp block (pending, warping, arrived, a block cleared before it ran, and one
  that never ran: stuck);
- `game_sbo_test`: the SBO lobby's Join match, record states, why words and status line; the entry's guard in order, one
  entry at a time (`busy`, also while this run's warp still loads) and none while the slot's record is open (`record`),
  the save wait and its 30 s limit, the saved-file checks, the warp's guard, the arrival watch and its 60 s limit; the
  return's guard, the restore rule, the reload watch, SB's own reloads, the title recovery and the load of an open slot;
  `seq_pick`, which lets `coop sbo seq` run only one of the four sequence names the native part made;
- `game_preset_test`: the match loadout's call order, the slots it empties, refusals and read-back;
- `region_tabs_test`: the teleport screen's record list: the sanity check, the name lookup, the append.
- `loading_test`: the lift of the lobby arrival's black over a copy of SB's auto list: each entry of tag 5 gets lifetime
  0, SB's own entries and every other byte stay as they were, and a count out of range touches nothing;
- `camp_text_test`: Matrix XIII's camp names and the 25 records' words, the keys (unique, the region's ending in a
  letter), the language pick, when a pass is due and the `camptext=` and `recordtext=` lines;
- `camps_test`: the activated camps' read, each guard refusing with its own reason (a warp, a respawn or a logic
  task as busy), when the list is read (at once with none held, in a new world or after a drop, then every 2 s) and
  the `activated=` line (the list, the camp EVE respawns at, a refusal, names that would not split left out);
- `pak_list_test`: the `.pak` mod list's filter and digest (the base game's files left out, mods in any folder and
  any case counted, the listing's order and a name's case changing nothing, a size or a name changing the hash), the
  containers by name, the names as they go to the friend, hers against ours, the status list, and the CNS packs
  under `~mods` with their outfits and the `/Game` assets they declare (comments, other keys and a text cut short
  included), a `.utoc` directory index read into object paths (maps, other roots, encrypted, unindexed, cut short
  and looped indexes refused) and the shared list of containers both players have;

### Shared world

- `world_rows_test`: `world/rows.h`'s four lists strictly sorted, every SetEnvActive and no-progress row with states
  of its own, the lookups at both ends of each list and on near misses, and rows of build 26123051 each rule keeps or
  leaves out (a door and a lift with every state, the monorail without its camp-bound garage run, the crane without its
  camera states, the hyperdrive without its story states, a supply box, the boss cores, a story-only door, a Matrix
  XIII lever, a counter whose progress leads to an item, a quest's env control row, a monorail speed row whose chain
  plays a scene);
- `world_sync_test`: `world/sync.h`'s lines through format and parse and back (the largest legal line, 50 malformed
  lines and 20,000 fuzzed ones), the ring's capacity and wrap, the outbox that keeps the lines the link refuses, and
  two players' sides wired over the parser with a fake engine: the on and off lines and the answer to an on, a rejoin
  one side did not see, each gate on both sides, the lists on both sides (linked env lines part by part included),
  names without text, sequence numbers, lost and old lines, a load that reads no save for a while, the queue's order
  while loading and its overflow, the apply limit, the echo backstop, refusals logged once, a new partner and the
  status line;
- `world_engine_test`: `world/engine.h` over fake memory and fake game functions: the four roots read from their
  nodes (a named target, `self` through the owner env, an ObjectState of 0, a linked env inside and outside its
  owner's list or not live in our zone, values no line carries), and her lines applied: A1 and each of its guards, a
  Disable env changed as SB changes it, a tag that did not take, A2's records (found, made, a Disable one written),
  A1b live and offline, A3's call and its list check, A4's order (a None tag, an env already in the tag, a refusing
  guard), and the refusals for a missing world, player or name.

### Quests

- `quest_sync_test`: the shared quests' quest table, line format and parser (with a fuzz), the host's and the guest's
  rules, the zone marks, the steps made together and those that are not, the record file, and lost lines and
  reloads;
- `quest_engine_test`: the shared quests against a fake quest unit: the walk, the guards before each game call, the
  gate, a fault, two PCs through channel 2's text with delay and loss, a recording replayed into another save, and
  the worker's side (the gates that start and end a side, channel 2's lines beside the fight's, the record file and
  the status lines);
- `quest_own_test`: the mod's own quests in a fake quest unit (`quest/own.h`): nothing read off a co-op save, on SB's
  logic thread or before the world and the manager exist; the ID map through its inline and heap bits; the prologue
  and Quest_Epic_11 read beside "On Time"; each request word's one call (an acquire once, never when held; a first
  task's Complete only at that word's group with its task in progress, through SB's Complete and no other address);
  the answer word (every field through it, a value out of its 4 bits read as -1) and the `signalquest=` line.

## Python tests

- `save_guard_test.py`: `tools/save_guard.py`, its `slot` command included, on temporary folders;
- `install_test.py`: `tools/install.py`'s install, backup, uninstall and zip, on a fake game folder, and its `--pak`
  part: the copy of the three `zSBO_Lobby` files into `~mods` with a backup of the ones it replaces, a copy that does
  not hash like its source, a folder that lacks one of the files, the dry run, the refusal while the game runs, and an
  uninstall without and with the mod folder (the pak first, each into its own backup folder), all of them leaving the
  rest of `~mods` and `LogicMods` alone;
- `mxiii_rows_test.py`: `tools/mxiii_rows.py`'s two outputs match `data/mxiii-world.json`, its checks refuse bad rows,
  and the data holds the camps, bosses and mechanism rows the cooked map expects, with no warp switch left and the
  names of every new door, EnvC and ZoneEvent row chained. After a change to the data file, run
  `python3 tools/mxiii_rows.py` and commit the two files it writes;
- `mxiii_climb_test.py`: `tools/mxiii_climb.py --check` passes on the tree, every ladder, ledge and rope of
  `data/mxiii-world.json`'s move list, rebuilt as the game's construction scripts build it, lies within 2 cm of the
  editor's in `data/mxiii-climb.json`, and every ladder lands. The check refuses what the move list held before
  2026-10-31 (ladders lifted by their own height, sunk feet, other stacks, the landing on the wrong side) and the
  editor's stack at the 20 ladders where it does not land;
- `sbo_lobby_rows_test.py`: `tools/sbo_lobby_rows.py`'s two outputs, `session/sbo_maps.lua` and `lion/halls_rows.h`,
  match `data/sbo-lobby.json`, the module loads in Lua, the halls batch holds one seat row per kept seat but the camp
  ones (unique names that never end in `_<digits>`, unique IDs above build 26123051's highest), and its checks refuse
  bad spots, seats, names, IDs, fences and a batch of more than 255 rows. After a change to the data file, run
  `python3 tools/sbo_lobby_rows.py` and commit the two files it writes;
- `world_rows_test.py`: `tools/world_rows.py` on small made-up tables: each rule that keeps a ZoneEnvSpawnTable row
  out, each rule that keeps a state out (the player event types reached directly, through AddEvents and FinishEvents,
  through the states an env control row sets and through a progress control's change tags, the crane's camera tags,
  and ChangeState achievements on the state or on a state its events set), the SetEnvActive list, each ZoneEvent rule,
  the no-progress list, unknown names and loops in chains, Matrix XIII's rows from its data file, and the written block
  (sorted, between its markers, the rest of the header untouched, a name that cannot go into a C++ literal refused). After new
  table exports, run `python3 -I tools/world_rows.py <folder>` and commit `native/src/world/rows.h`;
- `matchmaking_scan_test.py`: a scan that fails if any script or native source could reach the game's matchmaking
  (see [night-operation-previews.md](night-operation-previews.md#how-the-original-matchmaking-is-blocked)). Stellar
  Blade's RunZoneEvent address is held once in `native/src/game/sbo.h` and called at two sites: once in
  `native/src/glue/tick/sbo_game.inc` for `coop sbo seq`, and once in `native/src/glue/tick/world_game.inc` for the
  shared world's env control rows, which `world/engine.h` checks against `world/rows.h`'s list right before the call;
- `sbo_difficulty_scan_test.py`: a scan that fails unless `native/src` calls Stellar Blade's difficulty setter
  (`sbo::kSetDifficulty`, 0x141cf3180) exactly once, in R8 after the return's reload. Called in game outside a
  Boss Challenge zone, the setter makes the game reload the save, and on 2026-11-12 the call the SBO lobby's entry made
  right after its warp did that and sent the player back to the saved spot;
- `release_test.py`: `tools/release.py`'s build, upload and publish steps and its refusals, with git, gh and
  `tools/install.py` faked;
- `save_read_test.py`: `tools/save_read.py` on GVAS bodies built in the test (the header, values, containers, the EVAS
  wrapper's checks, the byte-or-name guess, value paths) and its commands on saves in a temporary folder;
- `story_lines_test.py`: `tools/story_lines.py` on an invented 29-line example with a known digest, on
  `story_case.json` against `story_case.txt`, on what must leave the digest alone, and its commands on saves and dump
  files in a temporary folder. It also checks `float_repr.txt`, Python's `repr` of 2,331 doubles for the Lua side;
  `python3 tests/tools/story_lines_test.py --write` writes it again.
