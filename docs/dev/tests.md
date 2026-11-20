# Tests

The toolchain the tests need is in [Building](building.md#toolchain).

The tests run on the build machine, without the game. `tools/install.py` runs them all before every build. To run one
by hand, from the repository root:

```
lua5.4 tests/lua/online/partner/puppet_test.lua
python3 tests/tools/save_guard_test.py
mkdir -p build/host
c++ -std=c++17 -Wall -Wextra -Werror -I native/src tests/native/game/codec_test.cpp -o build/host/game_codec_test
build/host/game_codec_test
```

On Windows, `.gitattributes` keeps LF line ends in the checkout: several tests compare file text with LF patterns. A
clone made before that file keeps its CRLF files. With no uncommitted changes, `git rm -r -q --cached .` then
`git reset -q --hard` checks every file out again with LF ends.

## Lua tests

The Lua tests (`vehicles/bike/`: `drive`, `drive_model`, `fetch`, `model`, `off`, `others`, `park`, `ride`, `stand`;
`core/`: `actors`, `actors_of`, `class_at`, `effect`, `enemy`, `items`, `keep`, `keybind`, `line`, `link`, `mask`,
`pak_gate`, `picks`, `player`, `row_edit`, `settings_file`, `ue4ss_settings`, `unreal`, `where`, `worlds`;
`fight/bosses/`: `enemy`, `gardener`, `leviathan`, `lion`, `off`, `tendril`; `eve/`: `chainspin`, `emote`, `flight`,
`glide`, `off`, `wear`;
`cutmenus/`: `devmenu`, `mailbox`, `off`; `story/scenes/`: `lines`, `off`, `scene`; `fight/enemies/`: `off`, `wiring`,
`wiring_notices`; `online/group/`: `group`, `off`, `region_tabs`, `travel`; `online/lobby/`: `arrival`, `commands`,
`halls_rows`, `off`, `sbo`, `wiring`; `online/lobby/ui/`: `lobby`, `lobby_model`; `main/`: `bike`, `boot`, `collide`,
`guide`, `gun`, `idle`, `input`, `keep`, `loader`, `match`, `menu`, `scoreattack`, `session_ui`, `settings`;
`world/maps/matrix13/`:
`off`, `words`;
`world/maps/matrix13/quest/`: `on_time`, `subtitles`, `zone_talks`; `world/maps/matrix13/talks/`: `zones`;
`world/maps/matrix13/level/`: `boss`, `breakables`, `drone`, `fans`, `mila`, `move`, `travel`; `online/modes/nightop/`:
`board`, `challenges`, `guard_text`, `off`, `probe`, `recruiter`, `recruiter_text`, `roxanne`, `run`, `shop`, `waves`;
`online/partner/`: `bike_part`, `capture`, `doro_pick`, `ghosts`, `hud`, `off`, `puppet`, `sentinel`; `online/photo/`:
`off`; `story/quests/`: `off`, `wiring`; `online/modes/race/`: `commands`, `doro`, `drive`, `drive_model`, `model`,
`off`, `run`; `online/modes/scoreattack/`: `board`, `challenges`, `game`, `model`, `off`, `round`, `run`,
`scoreattack`, `waves`; `online/saves/`: `off`, `saves`; `online/session/`: `booth`, `chat`, `commands`, `join`, `off`,
`wiring_cycle`, `wiring_dlc`; `online/session/ui/`: `create`, `create_model`, `sessions`, `sessions_model`;
`world/daynight/`: `daynight`, `off`, `rule`, `wiring`; `story/together/`: `off`, `snapshot`, `wiring`, `wiring_dump`;
`ui/`: `text`; `ui/kit/`: `guide`, `hud_parts`, `kit`, `model`, `notice`, `pause_tab`; `ui/text/`: `culture`;
`world/objects/`: `off`, `wiring`;
`fight/gunmode/`: `cost`, `engine`, `helpers`, `nikke`, `off`, `online`, `release`, `slot`, `state`, `stock`, `stop`,
`texts`)
run the scripts, with fake UE4SS objects for those that call the engine. In the capture test, any write to the fake EVE
fails the test. The `main/` tests load `main/fixture.lua` first, with UE4SS stubbed for `main.lua`. Each module's
`off_test` runs `main/isolation.lua` with its name.

- `online/modes/race/commands_test` covers `coop race look on` refused while EVE rides the bike, with nothing asked of
  the Doro look, then started once she is off; `online/modes/race/drive_test` covers the races' drive probe and its off
  refused while she rides;
- the copies' tests (`vehicles/bike/drive_test`, `vehicles/bike/drive_model_test`, `online/partner/doro_pick_test`,
  `fight/bosses/enemy_test`) hold their originals' cases for the module's own copy; `online/partner/bike_part_test`
  covers the tagged bike part found by EVE's address; nothing for another mesh, no tag or another EVE. The tests of the
  helpers moved to `core/`, `ui/kit/hud_parts.lua` and `ui/text/culture.lua` hold one case each from the tests of the
  files they left;
- `vehicles/bike/model_test` rides `vehicles/bike/model.lua` on flat ground with Eve On Wheels' default values: 90% of
  the top speed after 3.9 s, a real top of about 2252 cm/s, 15.8 m of braking from the top, reverse after 0.3 s at a
  stop, the yaw rate and lean at full lock at five speeds, the drift's 42-degree slip cap, a wall, the air, a ramp
  launch only after 0.12 s of climb, the pitch, root motion holding the state and the values' bounds;
- `fight/gunmode/helpers_test` covers gun mode's pure parts: its settings as `core/link.lua` parses them (the defaults
  without them, `gun_key` with its modifier or none, its test lines with refusals), the polled keys' edges and D-pad
  Right's tap (a hold is the bike's), the crosshair point in EVE's frame and the rifle's magazine (a round per cool
  time, the reload when empty or lowered part-spent, the HUD count, no round once the spares are spent, a refill). The
  reticle's round slot shows the round's name, the reload word and the empty word in the menu's language. It reads
  the words once a second, not on each frame. It also covers `mode.lua`'s point along a camera's forward and its eased
  step, then the rifle layer's clip paths (one folder, object paths) and its mesh records: an earlier load's record
  keeps the first class listed. Last, `ik.lua`'s quaternion math against UE's conventions: rotator to quaternion and
  back, a vector turned, two turns in order, a frame's rotation and a frame made orthonormal;
- `fight/gunmode/cost_test` counts gun mode's engine calls over `fight/gunmode/fake.lua`. With the rifle away (parked or
  not) 600 frames look up nothing, never ask whether the game is paused and poll two keys a frame (`gun_key` and D-pad
  Right). A press while the game is paused does nothing. The dev facts probe still waits out a pause. With no player
  controller `FindFirstOf` runs once a second at most. With the rifle out no `/Script` object is looked up again, the
  rifle-first solver (`ik.lua`) included. The crosshair is traced only while she aims. The zoom keys go unpolled in the
  game's own aim. The drone and the reticle's text are walked for (`FindAllOf`) once at the rifle out. The text is
  walked for again at each firing mode entry. The drone is walked for again when the one held goes, or 10 s after a miss
  at the next rifle out. A frame of the posed stance reads no bone name and makes no FName;
- `fight/gunmode/engine_test` covers the engine objects gun mode keeps across frames, over `fight/gunmode/fake.lua`.
  Masked keys go back into the action mappings as they are when the rifle goes away, after coop fly's mappings moved
  the array to a new buffer; nothing is written into the old one. The muzzle flash's asset is found by its path or
  loaded again once collected. It is never spawned freed or through a reference kept from an earlier flash. Over a
  fake of its own, the posed stance keeps the hide clip held by a component of its own (in single-node mode) while the
  donor plays the reload;
- `fight/gunmode/online_test` covers what other players get of gun mode, over fake UE4SS objects. The posed stance
  adds no skeletal mesh component to EVE. Its donor and the keeper of its hide clip stand on an actor of their own,
  removed at stop, so the ghost's capture never sends them. The laser sight is spawned at the rifle's muzzle with no
  parent (the capture sends the rifle's attached effects). Each frame of aim moves it to the muzzle, on the rifle
  layer too when it has no point to end at. While an SBO match runs the rifle does not come out, with the match notice
  once in 3 s. A match that starts with the rifle out puts it away within 0.25 s with everything back;
- `fight/gunmode/slot_test` covers the D-pad rifle slot (`fight/gunmode/ui/slot.lua`) over a fake kit, then through
  gun mode over `fight/gunmode/fake.lua`. At the rifle out SB's slot widget is made at render scale 0.6 with the rifle
  icon set and `rounds | magazines` written. The count follows the rounds while firing. Only changed numbers are
  written. The icon is looked up when a part is made, never on a frame. The kit's pause is read every 0.25 s.
  The slot hides at a pause, when the rifle goes away, in the photo mode, after a new controller and at stop. A part
  that a root rebuild left behind is made again. When the kit refuses the part, the kit's image gets the icon before it
  shows and a `num` text shows the count. Once the refusal passes, the next kit build makes the part. While the keep
  serves the icon, no build looks it up by its path. The slot wants the icon from the keep and warms the leaf's class.
  Without the icon the count shows alone with one log line. With `gun_mode=off` no group is added;
- `fight/gunmode/stop_test` runs gun mode over a fake UE4SS (`fight/gunmode/fake.lua`) on the rifle layer's path. The
  fake's row fields have the kinds read in Ghidra on 26123051: the shot's Hit1 step has a byte `Type` and no `StepType`.
  `stop` (coop off) gives back the table fields, the keys, the rifle, her body's own post-process class, the FOV lock
  and the layer's arms; with `gun_fire=own` too, where the fields stay changed after the rifle goes away. After it no
  key, toggle or new controller does anything. A second load over the same game and `coop-gun.txt` puts back what the
  first left with the rifle out. Its own rifle then takes and gives back the shipped values. A start puts back what an
  earlier load left before it reads the rows. `coop-gun.txt` keeps floats, integers, booleans, strings, FNames and
  vectors exactly. A start whose input mask or rifle fails gives back what it took, as does a start that raises once the
  rifle layer is on. A new controller clears the old pawn's state at once; its deferred reset shows the drone, puts her
  facing back and takes the layer off her new body;
- `fight/gunmode/state_test` runs gun mode over the same fake against the game's state. While the rifle is out the
  shot's Hit1 step has its Cast1 step's `Type`. The shipped value comes back when the rifle goes away. The shot's two
  borrowed fields keep their shipped values while the rifle is only out. They change at the first shot through the zone
  event (kind 2 on the borrowed row) and go back 1 s after the last one, later after a pause. `coop-gun.txt` lists them
  while they are changed, so a Lua reload puts them back. A pause gives the masked keys back (`coop-gun.txt` drops
  them); the first frame after it masks them again. The rifle does not come out in a cutscene, an interaction or its
  block, with her movement held, in a swim, a flight or a custom movement mode, or in the photo or selfie mode. Each of
  these puts it away within 0.25 s with everything back. A jump keeps it out. Another module's hold on EVE (`busy`)
  refuses the rifle or puts it away the same way; `out()` says whether it is out. A refused toggle (no EVE, the drone
  aim held, a state that holds her, a failed start) gives its notice. F4 toggles the rifle by default, G does not; a
  key with a modifier needs it held; `gun_key=none` has no key. Once `menu_key` is Shift+F4, also from a rebind
  after the load, Shift+F4 is the menu's press only. F4 alone and Ctrl+F4 still toggle the rifle;
- `fight/gunmode/texts_test` holds gun mode's texts to its code and scripts. The rifle layer's pak has one name, the
  one its build script writes (`zNGMSpike_P`), with the class `fight/gunmode/overlay.lua` looks for: no other pak or
  layer name in gun mode's code, tools, page or NOTICE section. The page and NOTICE name both. NOTICE names Mixamo.
  Each script in `tools/gunmode` starts with the SBO license lines. Its comments name no script that is not there and
  hold no session notes. The Blender and Unreal scripts stop without `NGM_TOOLS` and import into no shipped game folder.
  `export_stand.py` opens by default the `.blend` that `retarget_mixamo_stand.py` writes. The tools' README names each
  script, the rifle layer, the `NGM_R_` clips and `SBOutfitProject`. Gun mode's code, tests, tools and page hold no
  clock time of a play session unless it names its log (`UE4SS.log 2026-11-12 21:49`). They cite neither
  `NGM_FACTS.md` nor the rebuild's plan, which are not in this repository. The gun mode page names every table
  `fight/gunmode/data.lua` changes and the notice the parked key shows. While `mode.lua` passes the rounds no D-pad
  slot, neither the page nor `ammo.lua`'s header promises the `rounds | magazines` count. While it passes one, the
  page says what the slot shows, names its icon (`Icon_Nikke_LostItem_AssaultRifle`, row `Nikke_AR`) and says the
  first in-game test sets its place. The page, its docs index row and `coop gun`'s comment speak of no crouching.
  The page has no ", and" or ", but", no bold-label bullet and no
  "co-op session". `ammo.lua`'s header and `facts.lua`'s note on the retired F11 have no ", and" or ", but" either.
  Only `fight/gunmode/wiring.lua` registers an engine hook (`NotifyOnNewObject`, `RegisterHook`);
- `fight/gunmode/release_test` runs `fight/gunmode/release_check.lua` on gun mode's shipped defaults: no debug flag
  of `Config.DEFAULTS` is on. It first sees the check refuse a test-only line (`gun_facts=on`), a changed release
  value (`gun_aim_key`) and a debug default set on;
- `fight/gunmode/nikke_test` checks that every row of `fight/gunmode/rows.lua` says what
  `fight/gunmode/nikke_rows.h` writes, then the rounds over a fake status text: nothing is asked at the title, on
  your own save or on the manual co-op slot (`slot=coop` with `saves=main`); once a co-op save from the co-op save
  files has loaded it asks the `nikke` batch, again 10 s after a shut gate, at most 4 times a load. The magazine
  stays free before the read-back, after a refusal, a fault or rows that read back wrong (one log line) and a shut
  gate's refusal decides nothing. It is ready only while the rows are in and the last `slot=coop` or `slot=main` line
  said `slot=coop`. An unread status, `slot=none` and `slot=unknown` keep it. One unread status keeps a stocked
  magazine's rounds. A take that no read shows in 10 s of play is logged once. The
  count comes from the engine line's `items=` answer for gun mode's own ask number (20000 to 32767, never the one the
  engine line shows), read once a second while watched, with the takes no read shows yet taken off. A take calls
  `ServerRequest_ItemBucketItemRemove` with bucket 1, EVE's GUID and `Bullet_Nikke`. It is refused before the rows,
  while the game is paused, with no EVE or no GUID; `coop off` ends the rows' wait and the reads;
- `fight/gunmode/stock_test` runs `fight/gunmode/ammo.lua` over a fake stock: free magazines until the stock is ready,
  then an empty magazine, one take per reload of at most a magazine and at most the count, the spares as the count, a
  refused take that loads nothing and a wait of `Ammo.RETRY` (5 s) before the next empty reload (also for a
  part-filled magazine fired empty), an empty magazine
  that reloads once rounds come, no round while none are carried (`out of rounds` logged once), free magazines again
  once the stock stops being ready, a new world that keeps the magazine and the rifle put away mid-reload that takes
  once;
- `vehicles/bike/ride_test` covers `vehicles/bike/ride.lua` over a fake EVE and native part: the preload asked once and
  released at `bike=off`, the part made once (at the seat, hidden, its tick off) or found again after a reload, every
  mount refusal with its reason and nothing written, the mount's order and the dismount backward, the lean (the math
  library looked up once a ride), the riding pose played again or ending the ride (read in the 250 ms pass only: no
  frame reads the status), the 250 ms checks (EVE down read from the status line's `bike_life=` with no session, or from
  the session's life state without that word), `coop-bike.txt` and its restore after its own drive's
  (`vehicles/bike/drive.lua`), `coop bike status` and `tune`, a mount refused while the races' drive runs, `idle_part`
  (the part the capture leaves out) before the part, on and off the bike, after a ride ended on a fault, after a reload
  and at `bike=off`, the part's `SBO_Bike` tag (a tag that does not hold makes no part), the earlier load's part found
  at a reload's first tick with the preload at `fault` and removed by the first pass at `bike=off`, another mod's
  component on the bike's mesh never hidden, used or removed. With a fake `vehicles/bike/stand.lua` it covers the parked
  bike: made after the part, parked where a dismount by the key leaves her, at the last ground pose after a forced one
  (none kept on a `Movable` base) or where it stood before the mount, hidden while she rides or a cutscene holds her,
  removed for a new EVE; a mount refused far from it (a bike 300 cm straight below her is `3 m away, ahead of you`), on
  another map or before it is back, else made onto it by a teleport, or where she stands when the teleport is refused;
  the prompt once each time she comes within reach; the record per account and save (a Load Game during a ride writes
  the old save's record, a park made before the first key is written at that key, an unreadable file, nothing read or
  written in an SBO lobby); the stand's path swept after a reload, a reload while she rode parking at her feet, `coop
  off` and `bike=off` removing it with its place kept; its bike line at each change, sent again after a failed write;
  the paid fetch at a Xion camp (offered after a far or another-map refusal, paid by a press within 5 s, one start for
  every press during the payment, too little money and a failure said, never within reach, in an SBO lobby or away from
  a camp; the money's name from `game_text` on the screen's words, `betacrystal` in the English copy of another
  language, for a name over 32 bytes and in an offer past 200 bytes); the paint of the part and the parked bike for
  EVE's outfit within a second, put back for another outfit and on the part at `coop off`; a parked bike made after
  `coop off` at the freed address and path of the removed one painted again; the `paint on for <mesh>` or `paint off
  for <mesh>` end of `coop bike status`;
- `vehicles/bike/paint_test` covers `vehicles/bike/paint.lua` with fake UE4SS objects: the shipped table passes its
  check with one entry, a `Base Color Tint` on slot 1; the check takes a name with spaces (`Base Color Tint`),
  punctuation (`A_b-1`) or a `}` and refuses a slot out of 0 to 3, an empty or 65-byte name, a control character, a
  `~` or a byte above `~` in a name, a value that is not four numbers from 0 to 100000 and a key that is no object
  path; each instance made from the mesh's own material; one step a second, one paint per component and mesh, one
  clear for a mesh with no entry; an earlier Lua load's instance cleared; a component at a new address, or at the same
  address with another path, painted again; a failed call logged once per component and mesh with the slot left as the
  mesh made it; a table that fails its check logged once with nothing painted;
- `vehicles/bike/park_test` checks `vehicles/bike/park.lua` with `lua5.4` alone: the reach (200 cm across, 100 cm up or
  down, from any side), the whole metres and the side from the camera's yaw (never `0 m`), the seat a mount lands her
  on, the spot a dismount parks at, the clearance from her capsule to the bike's and the open-then-solid rule, a map's
  name, the record's file from the status lines with its line read back (a line of another version, a bad map, a
  position past 10,000,000 cm, NaN or an angle past 360 degrees read as unreadable) and the bike line read back (none,
  or one the native part would refuse, read as no place);
- `vehicles/bike/stand_test` covers `vehicles/bike/stand.lua` with fake UE4SS objects: the parked bike made hidden and
  closed, `WorldDynamic`, blocking every channel but the camera, no overlap events, never stepped on, a cull distance
  only when given; placed by a teleport; shown and hidden with its collision; open while EVE stands inside it and solid
  once she is 20 cm clear, with one log line; a sweep that takes only an actor whose root shows the bike;
- `vehicles/bike/others_test` covers `vehicles/bike/others.lua` over a fake stand and EVE: other players' parked bikes
  as copies on our map only once our EVE stood 2 s, one made a pass, moved in place, removed with their reason (none,
  another map, a member gone), never ours, none with `bike=off` or the mesh not ready, hidden in a cutscene, solid
  against our EVE once she is clear, their paths kept for the next Lua load's sweep, all removed at `coop off`;
- `vehicles/bike/fetch_test` covers `vehicles/bike/fetch.lua` over a fake EVE, player controller and native part: the
  price and its timings, the count asked first, one payment at a time, too little money refused with the count and
  nothing removed, an answer to an earlier ask never counted, the remove's five arguments (`1`, her GUID, `BetaCrystal`,
  `500`, `-1`), paid once the count fell by 500, paused time not counted toward the 10 s, a failure when it does not
  fall or when no answer comes, a read whose answer was lost (`coop gift`'s answered after it) asked again with its
  number after 1 s, the numbers from 32768;
- `online/partner/capture_test` also covers SBO's bike left out of the parts while EVE does not ride (`leave_out`, asked
  once a look): an outfit of 16 parts keeps them all; while she rides the bike is part 1 and the last follower goes;
  getting on or off starts a new generation; another component on the bike's mesh stays a part;
- `core/link_test` also covers the status's `uidev=`, `me=`, `world=` and `story=` lines and the `owner=`, `room=`
  and `hall=` fields of a match lobby's `link=` line, each read as nil without it (`me=` also when the name is empty)
  and never from a player's name; the `shared_world`, `shared_story`, `daynight`, `pause_tab` and `hide_popups`
  settings (the `sky=` line kept out of the `link:` lines); `bike` and `bike_key` (an older
  file whose keys hold F3 gets no bike key); `gun_mode` and `gun_key` (F4 by default, G refused, an older file whose
  keys hold F4 gets no gun key, a clash both ways) with gun mode's test lines, kept as written with no note. It also reads the `dlcs=` line with the `dlc_missing=` and
  `dlc_extra=` lines after it, the `mycycle=` and `cycle=` lines (a value out of range dropped), the session list's
  `list=` line with its `session=` rows (a row only after a `list=` line, `-` read as none) and a joiner's `wait=`
  line, logged once a wait. It covers `who_can_join` (`public` by default, the older `code` and `private` read as
  `invitation`) and `friends_ask`, the `where` and `rules` requests
  asked only on a change and never with a word the native part refuses. The rules word is built from the settings and
  read back in that shape only. The parked bike's line goes to `coop-parked.txt`, the newest replacing one the native
  part has not taken. Each member's `bike_of=` line reads into `bikes()` by her SteamID and stays out of the log;
- sessions of more than 2 players: `core/link_test` reads `max_players` (2 to 4, 4 by default and in a new file; any
  other value refused with a line, `4` kept), every `pending=` line in the status's order (`pending()` the first,
  `pendings()` all of them), the `host=` and `vit=` lines (`vit=` kept out of the log, a malformed line read as none),
  `others()`, `crowd()` and `Link.crowd()` with the `players=` line (a member the host let in counted before her link
  with us is made), `cap()` from the `host=` line's `max=` (none for `max=0`, read again after a Lua reload), the status
  line with ` +<n>` (`Paused by` naming the host alone), the first member past the handshake standing in on a host whose
  pair left, `ping()` the round trip of the member the status line names once she is past the handshake;
  `online/session/commands_test`, `main/boot_test`, `main/menu_test` and `main/session_ui_test` the host request ending
  with `max_players` (`main/session_ui_test` also the members' rows after the arrow in the kit's order);
  `ui/kit/model_test` the Players row on the Options page and its mute rows (one per other member past the handshake,
  under Chat, the same row each call, Select giving `mute`, her SteamID and whether she is muted); `main/menu_test` a
  mute row's words and its `coop mute` or `coop unmute`; `online/session/ui/create_model_test` and
  `online/session/ui/create_test` the Players row of the Create a session screen (held at 2 and 4, the scroll window one
  row longer); `online/lobby/ui/lobby_model_test` a session counted against its host's `max_players`, against 4 while it
  is not known; `online/session/join_test` the host's queue (one question about the first joiner with the players
  waiting after her on the seconds' line, then the next one's own question with its keys dead again for 1 s);
  `online/partner/hud_test` the members' rows (right of the card, three to a column, six made, clear of the card and of
  each other at every `ui_scale` from 75 to 150 and moved for it; her name, HP and state as on the card, greyed, the
  alert once on DOWN and once on a lost link; hidden with `partner_card` off, while paused, out of a session and in a
  match lobby) and the card following the first member past the handshake on a host whose pair left;
  `online/group/group_test` the revive with three players (the nearest member alive within 2 m named in the wait, the
  call and the revived notice; the wait naming the member alive on our map when she is far; no member alive), each
  member's down notice with our revive of her, no down notice nor revived notice for a guest outside the pair on the
  host and on the pair, her own game waiting on no shared fight, then the guest's cutscene pause read from the host's
  slot, then the theater field: no walk for the group's cutscene, a faulted field walking as before;
  `online/group/travel_test` the host answering `camps?` while any guest is linked and the guest reading the host's map
  from his member line's slot (no offer while that slot has no ghost or the host is not linked);
  `online/partner/ghosts_test` `get(k)`; `cutmenus/mailbox_test`, `online/modes/race/run_test`,
  `online/modes/nightop/run_test`, `online/modes/nightop/roxanne_test` and `fight/enemies/wiring_test` a gift, a race, a
  run, Roxanne's pick and the PvP test refused with 3 players, `online/modes/race/run_test` and
  `online/modes/nightop/run_test` also a race and a run under way ending with their reason when a third player gets in,
  on the pair too while her own link with that player is not made; `ui/kit/guide_test` the first page's player count,
  the default `max_players`, in every language; `story/quests/wiring_test` the host's quest notices naming the guest
  whose side came on first and the guest whose ahead line it is;
- `online/session/commands_test` covers `coop host` with each of the four words (`ask` added under `public` and
  `invitation` with `friends_ask=on`), `coop host` alone (the Create a session screen when it opens, else
  `who_can_join`), `coop list` (a search by tab; alone, the last list numbered or a Public search) and `coop join
  <row>`;
- `core/unreal_test` covers `game_text`: nothing asked while the string table is not loaded or its id is no name, nil
  for a missing key, an empty text or an error, another table's key read by its path;
- `core/keep_test` covers `core/keep.lua` over a fake native part and a fake lookup: off without its setup; the whole
  list in one `coop-keep.txt` a pass (70 paths asked in one tick, one write of 70 lines), written again every 4 passes
  while the native count lags; a bad path logged once and never kept; the status read once a pass by `slow()`, never by
  `ready()` or `get()`; no lookup before the native part settled, one a pass after it, none marked while the soft path
  is not proven; a held object whose full name changed dropped and found again; a path missing on this PC logged once
  and never looked up again; a path asked after it settled waits again; off for the Lua load on `keep=fault`, on an
  `engine=off` line (another build, an engine fault, `coop_off`) with its reason alone in the log line and after 40
  passes with no progress; 128 paths at most; `LoadAsset` and `StaticFindObject` never called; `main/keep_test` the
  keep set up by `main.lua` with the link, `coop-keep.txt` written by the 250 ms pass and the pass that turns it off
  after `coop off`;
- `core/class_at_test` covers `object_at`: no walk before the proof, the soft object path once proven, the walk once the
  proof failed; `core/actors_test` a path the keep serves never loaded by `Doro.resolve` (nil when it is missing), the
  find and the load as before until the keep is ready; `story/scenes/scene_test` Lily's five assets wanted, `ready()`
  following the keep and a Lua load's restore that loads no theater, then the theater field: no walk at a talk's start,
  the talk followed through the class hash, our own talk refused as ours, a faulted field walking as before;
  `world/maps/matrix13/quest/subtitles_test` a talk that waits for the keep with one line and no walk before it goes on
  (no wait while `coop scene` is off);
- `world/maps/matrix13/level/breakables_test` and `world/maps/matrix13/level/move_test` cover the keep's classes (and
  the ledge's mesh) wanted when the module is made, no spawn before the keep settled, then one find each for the game
  run with no lookup of a kept path and no `LoadAsset`, a second world included; `cutmenus/mailbox_test` the gift
  toast skipped (false) with no lookup while the keep has not settled, then its class from the keep; a class missing
  on this PC never loaded; `online/modes/nightop/board_test` the board's class wanted, no lookup or load before the
  keep settled, then the keep's class with no `LoadAsset`; a class missing on this PC never loaded;
  `online/group/region_tabs_test` the two hooks waiting for the keep, then installed from its classes with no lookup
  and no `LoadAsset`;
- `world/maps/matrix13/level/travel_test` covers SB's black over world 2800's setup with fake parts: up once at the
  first tick in a new world 2800 younger than 20 s, nothing ticked in its 0.5 s fade-in, 0.1 s a tick under it, the
  walks primed once, `loading lift` once both lists are done in that world, SB's own end after 10 s, no black for a
  world met late or one that cannot be shown, EVE's world read at most every 0.25 s;
  `world/maps/matrix13/level/breakables_test` and `world/maps/matrix13/level/move_test` `done(world)` true only once
  that world's list is spawned, with `tick(budget)` spending the budget given; `world/maps/matrix13/level/fans_test`
  the rotors walked once under the black, then a stale rotor found again by its owner's path with no walk, a prime
  with no rotor giving the STOP line with no walk in play; `world/maps/matrix13/level/boss_test` the boss bar's text
  blocks walked once under the black, then a gone block found again by its path, a prime that finds no block leaving
  the look to walk as before; `world/maps/matrix13/quest/on_time_test` the arrival talk waiting while the black is up;
  `world/maps/matrix13/level/drone_test` the hook tried once a stay, only once its class is found by name;
- `ui/kit/model_test` covers the four Who can join values and the Friends join without asking row, shown under Public
  and Invitation only, then the Online tab row named in `docs/players/interface.md`'s Options paragraph between the
  bike's key and Reset all keys;
- `online/group/travel_test` covers the host's row in the session list: the rules word at each change, the map and
  nearest camp at once on each map and once a minute at most, from the follow's spawn point read (read again a minute
  later when it found no camp), nothing in a load, as a guest or in a match lobby. A refusal is logged once. For the
  bike's paid fetch, `camp_near` finds an activated Xion camp whose spawn point stands within 10 m on Xion's map,
  walking the spawn points once a map;
- `core/mask_test` checks the masking of `UE4SS.log` on the cases `link_protocol_test` checks for the native part's;
- `core/pak_gate_test` finds the hall lobby pak `zSBO_Lobby` in `~mods`, else `LogicMods`, over fake files, checks its
  version (the `.utoc` size and the `.ucas` size from the `.utoc`'s compression blocks, joined by `_`) and that each
  read is bounded,
  and refuses a missing game folder, `.utoc`, `.pak` or `.ucas`, a map or folder missing from the directory index, and a
  `.utoc` whose header does not read as one;
- `fight/enemies/wiring_test` also covers `coop fight pilot` (its `test target` and boss tests included), `coop fight
  spawn probe`, the `spawn_filter` setting with the `filter` word it adds, and the `same_place`, `aggro`, `same_spawns`,
  `enemy_extra`, `bosses`, `boss_hp_scale`, `hit_reactions` and `stagger_resist` settings, whose rows `main/menu_test`
  covers with the `shared_quests`,
  `shared_world` and `shared_story` rows, and `coop pvp` (its words, the `pvp_spike` and `shared_enemies` refusals,
  status, and `pvp_spike=off` ending an earlier load's PvP test at a reload);
- `fight/enemies/wiring_notices_test` covers the same place and same spawns notices in both languages;
- `online/session/wiring_dlc_test` covers the DLC notice: once a session when the two lists of installed DLCs differ, in
  the menu's language with its English beside. The same DLCs, or no list yet, give none;
- `online/session/wiring_cycle_test` covers the New Game+ notice: the guest compares with the host, the host with each
  member; one notice a member while the values differ, one more on a change, in the menu's language with its English
  beside. The same values, ours not read yet, a match lobby or the SBO lobby give none;
- `story/quests/wiring_test` covers `coop quests` with the `shared_quests` and `quest_deny` settings and the shared
  quests' notices;
- `main/gun_test` covers gun mode's wiring through `main.lua` with a fake `fight/gunmode/mode.lua`: `coop-gun.txt`
  through the link's store (none without the native part), the photo and selfie modes as the runtime reads them, its
  `busy` reasons (the bike, the Doro look, `coop emote`, a hall seat, `coop fly`, `coop glide`), the SBO match it
  reads from the link (a round in play or the PvP test, none without the native part), its notices, the settings and
  words it gets (no unknown-setting line for its `gun_` lines), the file it reads itself without the native part
  (`gun_mode=off` holds), the restore at the first tick, `coop off`'s stop, the restore alone after a Lua reload
  with `coop off` still on;
- `main/bike_test` covers the bike's wiring (`vehicles/bike/wiring.lua`) through `main.lua` with a fake
  `vehicles/bike/ride.lua`: the load line, what the ride gets (its asks, `coop-bike.txt`, the driving, the settings,
  SBO's busy reasons with coop fly, gun mode's rifle and our open screens), `coop bike` and its words, F3 and the pad's
  D-pad Right hold with a refusal on screen, the hold ignored with its reason logged at the title, with one of our
  screens open or with the game paused, the restore, the frame and the 250 ms pass with an end said on screen, the
  Options rows, `coop off`; `riding()` as `coop emote`, the race, the hall seats, `coop fly on` and `coop glide on` read
  it; the ride's `idle_part` as the capture's `leave_out`; what the parked bike gets (the menu's words, a notice, SB's
  text by table path, the travel worlds, its record through the link's files, `coop-bike-stand.txt`, its bike line
  through `link.bike`, the paid fetch with `coop gift`'s FName and pause rules, the follow's `camp_near`); the other
  players' parked bikes built, restored at the first tick, run after the ride's pass and cleared at `coop off`;
- `world/daynight/wiring_test` covers the day and night cycle's wiring (`world/daynight/wiring.lua`) through `main.lua`
  with a fake `world/daynight/daynight.lua`: what it is built with (the native asks and status, the `daynight` setting
  (no cutscene or screen read), photo mode, Night Operation, the SBO lobby in Xion's training room only, the third-party
  plugin's path, `coop-sky.txt`, the world's address, no streaming level asked with no EVE, the star material wanted
  by the keep, `stars_ready()` false until it settled, then found in the keep with no lookup or load) and its 250 ms
  pass with `coop off`. It also covers `coop daynight` with each word and its usage line for the rest.
  `main/menu_test` covers the Day and night row: On by default, a change saved at once with no request. It covers the
  Online tab in the pause menu row too: On by default, a change saved at once, the next 250 ms pass asking
  `pausetab off` or `pausetab on`. The Hide popups online row: On by default, the load's first 250 ms pass asking
  `popups on`, a change saved at once with the next pass asking `popups off` or `popups on` once;
- `ui/kit/pause_tab_test` covers the pause menu's Online tab over fakes: nothing before the game is ready, the class
  loaded with its keeper and the Construct hook once, one button after the game's 8 with the word and the last button's
  style, none on a second Construct, the button again after a rebuild while paused, a click over the button or RB
  closing the pause menu once through the native part's close (the widget's CloseSelf never called), the co-op menu at
  the first tick after the unpause or the give-up line and notice after 2 s, a close refused for now logged once with
  nothing opened, a close that can never work stopping the tab with one STOP line and `pausetab off`, `pause_tab=off`
  making nothing and asking `pausetab off`, a refused ask asked again and logged once, a pause menu of another shape
  stopping the tab with one STOP line and `pausetab off`, then `coop off` stopping it; with the keep, the hook waiting
  until it settled, then installed from its class with no lookup and no `LoadAsset`;
- `world/daynight/rule_test` covers `world/daynight/rule.lua`: every row of the map table (keys in lower case, each open
  row complete for its kind of sky, the fixed maps, an unknown map), the rules in their order (SB's screens and
  cutscenes ignored, Xion's story night before photo mode, photo mode's hold whatever the hour, a test pin before Night
  Operation's midnight), the `sky=` line read into numbers (none from an older DLL), the command's hour (`24`, `-1`,
  `abc`, an empty word, `13,5`, `1e9`, `0x10`, `inf` and `nan` refused with the accepted range), the sky dressing and
  the star fade for an elevation, a SkyCreator's time, the real minutes to the night and the third-party plugin's path;
- `world/daynight/daynight_test` covers `world/daynight/daynight.lua` over a fake engine: one request per change, the
  map read once per EVE, the setting, each rule's case (Xion's story night read every 2 s), the command's words, a fixed
  map and the title, the status with an older DLL (no request loop), `coop off`, a refused ask and the third-party
  plugin's line once. Then the sky dressing: each dome looked up once per world and hidden once, a dome SB shows again
  hidden at the next 2 s look with one line, left to SB when shown at the next look too and tried again 30 s later, a
  missing one logged once, the star layer made once with its material loaded once a world and faded on change, the
  SkyCreators' time on change and back at an off, Xion's night dome shown through its actor, hidden again through it
  when SB shows it by day, shown again after its story night, a Lua reload at night that finds the star layer by its tag
  (no second one), an earlier load's dressing put back by a new load that starts off. Last, SBO's own maps: the Sun
  turned, its intensity, its colour and the SkyLight's intensity scaled, Matrix XIII's exposure bias lowered, each
  written on change only and put back at an off. Then the originals across a Lua reload at full night (the Hotel's
  lights, Matrix XIII's bias, a SkyCreator's time, each kept in `coop-sky.txt` with no compounding and back at an off),
  a new EVE in the same world, a new game run that reads the lights again and a `coop-sky.txt` that cannot be written.
  Spire 4's streamed sky sublevels: a dome that waits for its sublevel with no lookup, one looked up and hidden 2 s
  after its sublevel came (not before) with the SkyCreators listed again, one dropped when it went, one looked up again
  after it went and came back between two reads, one SB showed again told once across its sublevel's return, a
  SkyCreator sublevel with no dome, nothing read off the live passes and a sublevel that came meanwhile looked up at the
  first live pass, a streaming level whose read raises; the Terrace hall left alone; with the keep, no star material
  loaded at dusk until it is in;
- `world/objects/wiring_test` covers `coop world` (its words, on and off whatever `shared_world` says, status), the
  start once a load with `shared_world=on`, the end at a reload with `shared_world=off`, and the shared world's two
  notices;
- `story/together/wiring_test` covers `coop scenes` (its words, on and off whatever `shared_story` says, status, an on
  or off before the load's request that cancels it), the request once a load only where the `story=` line and
  `shared_story` differ (none off the pinned build or after `coop off`) and story together's two notices;
- `main/idle_test` counts the FindAllOf and StaticFindObject calls of the two loops (`main/frame.lua`, `main/pass.lua`)
  over one idle minute, each case from a fresh Lua load: 4 and 5 in a world with the UI up, 0 and 2 at the title, all in
  the first second;
- `main/collide_test` covers the ghost's collision through `main/pass.lua`: as `collide` says, never solid during an SBO
  session;
- `main/loader_test` covers `main/loader.lua` alone with fake modules: every export the stub before any `new` runs (also
  the exports of a module whose require raises, read from its `wiring.lua`), the modules in list order, an on module's
  exports as its `new` left them, its words in `M.commands` (a word defined twice raises), a require, a `new` or a build
  step that raises turning that module alone off (one log line, its traceback, its exports back to the stub, its words
  gone, its later build steps skipped), a manifest with `needs` raising, `view` and `get`;
- each module's `off_test` (`vehicles/bike/off_test`, `online/partner/off_test` and the rest) runs `main/isolation.lua`
  with its name: its require, the start and the end of its `new` and each of its build steps raise in turn. Each time
  `main.lua` must load with every other module on, run three frames and four passes, then a linked session with the UI
  up, every key bind and hook, `coop ui reset`, `coop off` and `coop status`, with no other module's off line, no `OK:
  nil` or `STOP: nil`, the off notice with the module's English name and each guarded late read refused. The same run
  with every module on comes first. `vehicles/bike/off_test` also checks that the capture leaves out an earlier load's
  tagged bike part while the bike module is off;
- `main/input_test` covers the controller's events from a fake `coop_pad` (routed to the menu, the co-op saves'
  question, the two boxes and the host's question, which ignores them for 1 s and never takes View held; LB, RB and Y
  taken and doing nothing there; the Online tab's event 12 going to the pause tab only, the open menu and the host's
  question keeping their focus; at most 8 a frame; an older DLL without it), the Online tab's close from a fake
  `coop_pause_close` (its three answers, an older DLL without it), the mouse in the menu and on the host's question (a
  left click going to the pause menu's Online tab while a pause menu holds it), the focus watchdog's reset, the Lua
  frame time line with its longest frame and 250 ms pass, their counts over 16 ms and over 50 ms, and the longest call
  of five modules, and the gap lines (a frame over 100 ms after the last, with the 250 ms pass in the gap or none, at
  most 200 a minute), then `INSTALL.md` and `docs/players/interface.md` both saying the mod reads any controller the
  game reads;
- `main/match_test` covers `coop match` (search, create, cancel, end, join with a code, leave), search and create with
  the SBO lobby's room and hall words, `coop mute` and `coop unmute` with their usage line, `coop block`,
  `coop unblock` (a SteamID or `all`) with their usage lines and `coop blocked` (the count from the status for one
  player or more, or no status yet); a SteamID and a join code
  masked in the log; the 4 digits shown after `***` taken for the one member whose SteamID ends in them (by
  `coop mute` and `coop remove`) and refused when two members or none have them;
- `online/lobby/wiring_test` covers `coop sbo` and the SBO lobby's wiring (the arm at the recruiter, the tick, the
  title's put-back, coop off) and the recruiter's auto spawn pass every 250 ms on any save; then the lobby's input
  routing (menu_key, the pad's View, LB and RB, the keys with C's tabs on QWERTY and AZERTY, the mouse), the hall seats
  (menu_key and View held 1 s stand EVE up while she sits, sit her near a seat SB's chairs left to menu_key, else open
  B; the hint says Sit or Stand up, and hides while B is open; a seat read that raises is logged once and the rest of
  the 250 ms pass runs), the engine calls behind SB's chairs (the class found in memory or loaded once, with LoadAsset's
  own error when it does not load, the deferred spawn in EVE's world with AlwaysSpawn, EnvActorName set before
  FinishSpawningActor, each part hidden with its collision off, the actor destroyed when a step raises, and the zone and
  row SB bound it to), its view and what its rows ask for (Search with the SBO lobby's room and hall words, Private with
  the map picked on the settings screen, which is not written to `coop-settings.txt`), the score attack's rows (the
  host's pick in the view while `scoreattack=on`, the mode picked kept for the Lua load and out of
  `coop-settings.txt`, Select on Challenge cycling the pick over what the room offers), the countdown feed, the start
  line (a score attack round's start logs its mode; its end line opens B again, once), the focus watchdog and the `hud hide` requests (`off` at the first pass after a load, then `on` and `off` once
  each as the screens open and close, and one that cannot be written logged once and asked again; `main/fixture.lua`
  keeps them apart from the other requests); last, the arrival's hold: after a lobby warp, ClientRestart's hook puts
  SB's black up at the next pass (`LoadingScreenFadeAuto` with a 10 s lifetime, 0.5 s fades and tag 5) and veils the
  kit; `hud hide on` is asked under it from the arrival on, passes before the lift; the menu camera takes the view while
  B waits, and once nothing is missing `loading lift` is asked, the veil goes and B opens in that pass with SB's HUD
  still hidden; a Lua load under an earlier load's hold asks `loading lift` once, at its first pass in the lobby world
  and not before, and none when that pass also puts up its own black (one fade); without the hook, one log line;
- `online/modes/scoreattack/model_test` covers score attack's round without the game: the challenges planted rooms
  offer, the host's pick and its Random draw, the score texts and their refusals, a run's result, the host's checks
  against honest and inflated runs, the ranking with shared places, then the host's wait over a fake clock (ready,
  done, refusals, leavers, a late ready, the deadline, the rank text and the match's end).
  `online/modes/scoreattack/round_test` covers the round on a fake link and clock: the host's draw, go, checks, rank
  and match end, a guest's go read before its start line, her rank and a void, who may send which line, the pace of
  the now lines, a round that ends early, one replaced by the next, one found playing at a Lua reload, a room that
  offers nothing, a player who leaves, the pick and its cycle. `online/modes/scoreattack/game_test` covers each
  sit-out reason with its log line and notice key, a hall seat left first, the run at the spot facing the ring centre
  on the round's seed, the now lines while its waves play only and the done line of each outcome.
  `online/modes/scoreattack/run_test`, `challenges_test` and `waves_test` hold their Night Operation originals' cases
  for the copies, with what the copy changes: each start refusal with no spawn, a whole Target Practice run from a
  lobby spot, `best_match_targets` kept in `coop-records.txt` beside the solo bests, every abort and, after a death,
  the in-place respawn (its checks, its 10 s, its result line, the death screen hidden and shown again).
  `online/modes/scoreattack/board_test` covers the card, the in-round board and the result panel on a fake kit, their
  words in the game's language, the notices with the kit off and the HUD's STOP line. `main/scoreattack_test` covers
  the pass line and the `coop off` stop through `main.lua`, then the wiring on a fake run;
- `online/modes/nightop/recruiter_test` also covers the auto spawn at each Xion load (waits while the spawn point is not
  loaded or EVE is too far, one spawn a load, a guard kept after a Lua reload, none after `coop recruiter off`). It
  checks the arm call right after the spawn and at a guard already there, before any check. It runs the looks every 3 s
  until +30 s with a guard who comes at +9 s, one who never comes and one 4 m off the point;
- `ui/kit/kit_test` covers the veil (the root built and kept collapsed, the look warmed in one 250 ms pass, shown again
  at once, and a hidden world's root left collapsed), the menu's mouse cursor, the focus put back after a click, the
  focus watchdog and the focus line it logs as it fires, text shadows and wrap, fixed groups, SB parts and the keyboard
  layout from the game's device. It also checks that a root built while its look warms holds each texture it wanted once
  warmed, so a GC before the next build frees none of them. With the keep, every asset path and part class is wanted,
  no warm-up lookup runs until the keep settled (the root is built in its flat look meanwhile) and no `LoadAsset` runs
  after;
- `online/lobby/ui/lobby_test` covers the lobby menu and settings on fake SB parts: layout, rows, focus looks, the leave
  question, the countdown, the kit drawing that stands in for a part the game cannot make (row labels, settings items,
  the leave question with Yes and No, the countdown's seconds), the lines logged as the screens open and close and the
  question is asked and answered, the Map row of a Private match (left and right, the pick shown by its name), the
  three mode rows with the picked mode marked and the score attack's Challenge row (the pick beside it, a guest's
  locked and reading the host's pick, in tab MATCH too), and that
  no part is ever focused, clicked through or sent a call outside the allowed list;
- `online/lobby/ui/lobby_model_test` covers the lobby menu's rows, actions, status and members by state, the settings
  rows (the Map row only with no lobby open and the hall lobbies in use) and the countdown's resync. It also covers the
  mode rows: score attack picked first while it can play, a mode row picking the mode that Search and Private match
  ask for, the Challenge row of a score attack match lobby (the host's pick, locked for a guest) and tab MATCH's rules
  of each mode;
- `online/session/ui/sessions_test` covers the Sessions screen on fake SB parts: the search asked as it opens, the
  status line (SB's search word, the wait), Refresh and its stop, the 5 s gap, the tabs (SB's Comrades), the rows and
  their scroll window, the details pane and footer, Select asking to join, the mouse (a resting mouse moves neither the
  cursor nor the list), the closes by itself, the input given back, parts made again after a root build, the kit drawing
  for a part the game cannot make (rows, headers, hints, the tab keys) and the log lines. No part is focused or sent a
  call outside the allowed list;
- `online/session/ui/sessions_model_test` covers a tab's rows and status from the native part's list, what Refresh and
  Select ask for, the cursor, the region and camp keys and the rules word read back (any other shape gives none);
- `online/session/ui/create_test` covers the Create a session screen on fake SB parts: it opens in a world on the values
  in effect, its rows, headers, right pane and hints, Left, Right and Select changing a value with the rows that come
  and go with it, the scroll window, Start and Back, the mouse (a resting mouse moves neither the cursor nor the list),
  a change not saved with its reason, the locked look and reason while `coop-settings.txt` cannot be read, the closes by
  itself and the refusals to open, the input given back, parts made again after a root build, the kit drawing for a part
  the game cannot make and the log lines. No part is focused or sent a call outside the allowed list;
- `online/session/ui/create_model_test` covers its rows for each Who can join value (Friends join without asking under
  Public and Invitation only), Shared enemies' sub-rows only while it is on, Shared story between Shared world and
  Shared quests, a setting Options does not define left out, a change written through `settings_file.set` and read back,
  Start and Back, the cursor and every setting locked with its reason while the file cannot be read;
- `main/menu_test` also covers Find a session: the Sessions screen opens in place of the menu and takes the keys (F and
  Q, E included), the pad (Y, LB and RB included; the bike ignored with its log line) and the mouse; the menu key, View
  held and `coop ui reset` close it; its view reads our protocol and game build from the status. It covers Host a
  session the same way: the Create a session screen opens from the main page, the co-op line and `coop host` alone,
  takes the keys (A, D and Q as Left and Right), the pad (the bike ignored) and the mouse; its view gives the settings
  in effect, its act writes a change as Options does and hosts Start's word; `host_key` still hosts at once;
- `ui/text_test` checks each language's notices against the feed's 200-byte line, the SBO lobby's notices included. It
  checks the lobby menu's rows, settings, values and status within their columns, the Sessions screen's hints, status
  lines, version and footer within theirs and the Create a session screen's title, header, Start row and right-pane
  words within theirs. The hall seats' Sit and Stand up hint stays within the booth hint's width. It
  also reads `link/core.h` to check that each join Steam refused has the same English line there and in
  `T.en.join_refused`, then that `T.join_refused` turns each one into every language's words. The DLC notice (`T.dlcs`)
  stays within 200 bytes in every language with 100-byte DLC names. So do the bike's refusals with the paid fetch's
  offer after them, with each side word and a six-digit distance or another map's 32-byte name and the longest key
  name. Score attack's notices stay within 200 bytes too (each sit-out, a round without a ranking, the end and the
  place with the UI off). Its screens' words stay within their columns: a board row's name and its score with the wave
  or end word, the result panel's heading, its line with the longest end word, its notes and the difficulty words;
- `online/lobby/arrival_test` covers the hold at a lobby arrival: nothing without a lobby warp or before its new
  controller; SB's black up and the kit veiled at the next pass; held while anything is missing, then lifted once with
  one line; the 8 s cap, which lifts whatever is missing and names it, also when the missing items cannot be read; a
  second warp under the hold (a guest following her host), which keeps the black and counts the cap from its own
  controller; a disarm (a refused warp, coop off); the 60 s arm cap; a black that does not show; and a lift the native
  part cannot take, which still removes the veil;
- `online/session/chat_test` covers the Thai leading vowels at a row's end;
- `online/session/join_test` covers the code box, then the join popups on a fake SB popup and on the kit panel that
  stands in for it. For the host's question: the popup filled before its Construct, SB's Accept and Decline, the cursor
  as its hover look, the seconds and a late name written on change only, the alert then SB's popup cues, the 1 s with no
  keys, pad buttons or clicks, left and right moving as up and down do, a left click answering with the button under the
  mouse (SB's own buttons or the panel's rows, nothing elsewhere), the mouse cursor shown, each player asked once a
  lobby, the 60 s left to the native part. For the joiner's wait: Close (a key or a click) leaving the lobby, a let in
  or a refusal closing it. Then `coop ui reset`, `coop off` and a name with `<` or `>`. It also covers the feed's join
  and leave lines in SB's words (`Join.feed`);
- `online/lobby/halls_rows_test` checks the hall lobbies' 181 rows (5 worlds, 5 zones, 171 seats) against
  `online/lobby/halls_rows.h` and `online/lobby/sbo_maps.lua`, then the title's ask: none without the lobby pak, once
  with it on the co-op save files, read back; a refusal, a fault or rows that read back wrong keep the lobby in Xion
  with one log line, also after a Lua reload, and a shut gate's refusal is asked again;
- `world/teamshop/shop_test` checks that every row of `world/teamshop/rows.lua` goes into ItemTable, ShopItemTable or
  ShopTable with the ShopTable row last, then the team shop over a fake status text and tables: on your own save
  `coop teamshop` refuses and the title asks nothing; on the co-op save files the title asks once with the three
  tables in the native part's order, then reads the rows back; the shop stays shut before the read-back, after a
  refusal, a fault or rows that read back wrong (one log line, also after a Lua reload) and a shut gate's refusal
  decides nothing; no `teamshopui=` line, its fault, the pause and an open under way refuse; the open's answer is
  logged (opened, refused, no answer in 5 s); `coop off` ends both waits; the command's argument and link checks;
- `world/teamshop/off_test` runs `main/isolation.lua` with `world.teamshop` (see the module tests above);
- `online/lobby/sbo_test` covers the lobby's spots, fence, row sets, notices and entry checks, and the entry and return
  from the status line, a double Join, a late arrival, coop off while warping and a Lua load in the middle of an entry,
  and a Join that enters again after SB's own reload cut an entry short (record open or warping); then the room shown,
  the spots and their re-place, the fence, hop and back, and a Lua reload in the lobby, with the log lines for the room,
  for where EVE stands one pass after a teleport and for each fence catch. It also covers an arrival whose status shows
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
- `story/together/snapshot_test` holds the in-game story dump to `tests/tools/story_case.txt` and its floats to
  `tests/tools/float_repr.txt`, the files `story_lines_test.py` checks the save side against.

## C++ tests

The C++ tests cover the platform-free headers in `native/src`. Each one sits in `tests/native/` in its header's folder,
and `tools/install.py` names its program after that path (`tests/native/game/codec_test.cpp` builds `game_codec_test`).

### Link

- `link_protocol_test`: the text protocol, with a fuzz loop, the requests from Lua (`coop fight` with its `place`,
  `aggro-host`, `bosses <boss %>`, `reactions`, `resist`, `spawns`, `extra <n>` and `filter` words,
  `fight stagger <0|1> <0|1>` and its `pilot` requests, `test target` and the boss tests included; `coop fight pvp` and
  `pvp off`; `lion rows`, `gardener rows`, `tendril rows`, `bolt rows`,
  `mxiii rows`, `shop rows` and `signal rows` with their 25 table words and bad addresses, the longest of them 813
  bytes; `fly` and `slowmo` on or off; `anim play` with its id, path and `once`, `loop` or `ride`, and `anim stop`;
  `bike load <clip>`, `bike free`, `bike gate on` and `bike gate off`, a mesh, a package path or a mod's clip refused;
  `shortcut list` and `shortcut load <map> <1-4>`; `hud hide on` and `hud hide off`; `pausetab on` and `pausetab off`;
  `popups on` and `popups off`; `loading lift`; `sky off`, `sky hold`, `sky cycle <hz> <H>` and `sky hour <minute> <hz>
  <H>` with their ranges; `world` and `scenes` with `on`, `off` or `status`; `nightshop`, `roxanne`, `lily`, `guardtext`
  and the 8 `signal` words, in `story/quests/own.h`'s order; the `sbo` requests (`on`, `arm`, `enter`, `warp`, `abort`,
  `leave`, `seq`) and their refusals, the score request), Night Operation's night line (its round trip, its refusals
  and a fuzz seed), the score line (Lua's text after `score`, printable ASCII up to the 512-byte message, never read as
  a race line, another protocol's refused, a fuzz seed), and
  the join codes (both real lobby ids, loose typing, malformed codes, and the share of one-character typos the check
  turns away), the masking of SteamIDs, lobby ids and join codes in the logs and the report (`masked`, with the numbers
  and words of the same shape it leaves whole), the match modes (`find_mode`: `ffa` and `scoreattack`, nothing
  else), `match search` and `match create` with
  their room and hall words (each refused when missing, extra, too long or not an alias word), `match cancel` and `match
  end`, `mute` and `unmute`, `block`, `unblock` and `unblock all`, the `host` words (`public`, `friends`, `invitation`
  with the older `code` and `private`, `closed`, then `ask`, then `max_players` from 2 to 4), `list
  public|friends|stop`, `where`, `rules` and the row cleaner, the match lines (start, count, end) with their bounds, the
  host's let and wait lines with theirs, the dlc and dlcs lines with their bounds, the DLC comparison by app id, the
  cycle line with its bounds (count 0 to 99, difficulty 0 to 2) and a fuzz seed, the bike line (`none`, or `park` with
  the map rule, three places within 10,000,000 and three angles within 36,000 as signed whole numbers), then protocol 24
  refusing a protocol-23 lobby and line;
- `link_core_test`: the link against the shared fake Steam, and two links through it with the handshake both ways,
  channel 1 and channel 2 with their checks, the photo line, the chat and vitals lines, Night Operation's night line, an
  Invitation lobby (its code, the invite dialog, the older words `code` and `private`) joined with its code and the
  host's approval of a player who is not a Steam friend (let in, refused, no answer, removed, a flood while waiting),
  with relay only set on both games before their first session with each other. A player on another protocol or game
  build: refused by the host, who keeps the lobby; left by a guest. A reject: from the host, the guest leaves; from a
  guest, the host stays. With a Steam that refuses relay only,
  nothing goes to that player and her session request waits; Steam is asked again 1 s later. After 3 refusals the host
  refuses her with a notice, or the guest leaves with one. A friend's session never asks. A join Steam refuses gets its
  notice for each answer Steamworks documents, or the number for any other. The block list: its fixed hash; its file
  with no SteamID in clear, written once for each change and read back with CRLF ends and other lines skipped; a removed
  player refused in the next lobby before any hello, with one notice and her session request ignored; `coop block`
  removing a member of the lobby we host; `unblock` and `unblock all` greeting her again at once; a guest's list never
  applied. The installed DLCs: read from the fake Steam at ready (installed ones only, the first 64, the app id for a
  name Steam leaves empty), sent after the paks line and again after her hello, hers ignored before the handshake and
  kept to 64, the status's `dlcs=`, `dlc_missing=` and `dlc_extra=` lines and one log line for each change. The cycle
  line: nothing sent while ours is unread, ours after our dlcs line, once for the same values, again on a change and
  after her hello, hers ignored before the handshake, the status's `mycycle=` and `cycle=` lines and one log line for
  each change on either side. The bike line: nothing before Lua's first payload, a payload `bike_ok()` refuses not
  kept, ours sent once to each member past the handshake and once at each change, a send Steam refuses sent at the
  next pass, ours sent again after her hello and her return from lost, hers as her `bike_of=` line after the
  `member=` lines (the latest only), gone when she leaves the lobby;
- `link_pose_cap_test`: the adaptive pose rate (`PoseCap` in `link/pose_cap.h`), one reading a second: a calm link and a
  lone bad reading never step; two readings in a row over the line (queue time or pending bytes) step down 60, 30, 20,
  to the first cap under the player's `send_rate`, never below 20; 10 calm readings step up one cap; a step up undone
  within its wait doubles the wait up to 80 s, and one that holds brings it back to 10 s;
- `link_match_test`: the fake Steam shared with `link_core_test` (`tests/native/link/fake_steam.h`, eight clients and
  the `Mesh` harness that runs several links in one test): the matchmaking exports named when missing, two co-op links
  through the harness, callback 506's log line, `me=` with our name after the first status line and no `owner=` in a
  co-op lobby, eight links in one match lobby (no approval, every pair linked, the owner's SteamID as `owner=` on the
  owner's and a guest's `link=` line, ghost slots 0 to 6 and a freed slot taken again, `friend=` from slot 0, the slot-0
  member leaving a lobby of three, whose `friend=` line goes while the third member stays linked and still gets our chat
  line, with no `mate=` nor `vit=` line and `<name> left.` on the owner only, the mods every member shares), an online
  session of `max_players` 2 refusing a third player, a lobby of an unknown mode left, each channel-1 message, channel-2
  line and chat line handed on with its sender, a channel-2 line to one member, `lines_from`, quick match (the exact
  filters and their order with the relay-only setting, a lobby created when none is found with its member limit and
  data, seven more searchers joining it, another version's lobby and a code match lobby never found, two searchers in
  one pass each hosting a lobby of one, merged into the lower lobby id when the lone host searches again 5 s later with
  her lobby's hall, the mover then reading the lower lobby's room, which the next searcher joins, one search at a time,
  a full first result skipped, a lobby created when every result fails, an unknown mode, a search refused in a lobby, a
  cancelled search), a private match lobby by code (Invisible, no `sbo_state`, its code, a stranger joining with no
  approval), the room and hall a created lobby carries and its `link=` line, a search that finds only lobbies of its own
  hall, a member reading both each pass and dropping a word `alias_word` refuses, the ICE setting given back in a co-op
  lobby, a joiner whose Steam refuses relay only sending nothing and leaving after 3 tries, the host's countdown (none
  alone, 10 s from two members with each member told, a member joining while it runs told the time left, 5 s once eight,
  stopped under the minimum, checked again at 0), the start (the lobby closed, `sbo_state` and `sbo_map`, one start line
  with the same seed and member order everywhere), `match end` and the next round's countdown and seed, the lines a
  guest refuses (from a member who is not the owner, a start without her), a code join after the start told the game is
  closed, a host left alone in a round in play, who does not search again, the host leaving (the lobby handed over
  before a menu leave, a crash, a silent owner, an owner change during the countdown: the round ends everywhere and the
  new owner reopens the lobby and counts down; a silent owner's countdown stopped on each guest once the owner is lost;
  a guest who drops out of a match lobby leaves without a rejoin), the stranger rules of a match lobby (a reject from
  the owner only, a mismatched hello refused by the owner who keeps the lobby and ignored by a guest, no photo or
  cutscene pause, gift, race, follow, night or shared quest line either way), floods (no pong past 4 pings a second; a
  member over channel 0's 128 lines a second for 5 s refused by the owner and by a guest, who both stay, her session
  closed and no reject every 10 s; 200 lines at once not refused; pose data before any hello, over channel 1's limit for
  5 s, refused; a guest leaving an owner who floods), the owner's round lines on a guest (a count line logged only when
  it moves her countdown, one notice for a start without her, past 8 a second dropped and logged once), the per-player
  chat mute kept for the run, per-peer pose caps (30 a second for a member of a match lobby, one peer's cap stepping
  down alone, one second of poses reaching peers at 20, 30 and 60 a second, tables always sent, an `SBE` sent to nobody
  as a match lobby has no pair) and the 60 s line of passes and full receive batches. Each of eight members' bike lines
  reaches the seven others, one state per sender. Score attack's lines in a match lobby of three go reliable to every
  member past the handshake. Each member's reaches Lua as `score <SteamID> <text>` with the SteamID from Steam; a
  text the line cannot carry never goes; past 16 a second either way they are dropped with one log line a minute; the
  counts have a line of their own beside the 60 s line, only in a minute that had some. Outside a match lobby a score
  line never goes and is never taken, with no log line;
- `link_group_test`: online sessions of 3 and 4 players through the same fake Steam: the pair (the host and the guest in
  slot 0) with the host in slot 0 on every guest, the host's let line with its `max_players`, the `host=` (with `max=`),
  `players=` and `vit=` status lines, 30 poses a second for a member who comes in past 2 players and for the pair's
  links once the third comes in, chat between guests, each member's parked bike reaching the three others in a session
  of 4; a joiner the guests hold (no hello, no session) until the host lets her in, after 15 s with no lost or back line
  either way, a removed member whose link each guest closes, a refused
  member who stays in the lobby and never links with a guest; the host's questions one at a time with each joiner's wait
  line; the host leaving, which ends every guest's session whoever Steam hands the lobby to; a guest leaving, announced
  everywhere; the pair leaving with no guest left, slot 0 then taken by the next guest let in; the pair leaving with a
  guest linked, the let line's pair 0 for one pass, then that guest in slot 0, named the pair with her notice; the pair
  leaving in the pass a Steam friend comes in, the guest already linked taking slot 0 and the friend a slot past it; the
  pair leaving while a Steam friend is in her handshake, her first let line naming her the pair with no notice; the
  pair's hand-over in the order the guests got in (a stranger who joined first and was let in last comes after a Steam
  friend who got in while she waited); Steam refusing relay only on a guest for another guest, which ends that link
  alone with its notice while the host's count (`players=`) still names her; the camps answers to the asker only, by the
  host's own number for each request (two guests' ids that meet, at once or one after the other, each answered once);
  gifts (an answer to an earlier gift still going), Doro races, Night Operation and a guest's photo pause refused past 2
  players, the guest told so, while the host's cutscene still pauses each guest; the pair rule (the notice once on each
  guest who is not the pair and never on the pair, an `SBE` to the pair only and none from another guest, a channel-2
  line to one member reaching her alone with its sender, the pair leaving dropping the shared fight's lines both ways
  while the shared quests' lines of the guest who stays go on); channel 2 per member (Steam refusing one guest's lines
  holds back hers alone, the pair's going on in order past `kFightQueue`, hers reaching her in order once Steam takes
  them, each refused line counted once); `max_players` 3 on a guest's `host=` line and refusing a fourth player;
- `link_list_test`: the session list through the same fake Steam, which follows Steamworks' read rules (no data for a
  lobby before a search returned it or `RequestLobbyData` was answered, `GetLobbyOwner` for members only, a result
  count, friends-only lobbies never in a search). A Public host's rows with `where` and `rules`, no relay only forced
  and no regroup alone; a host request with another Who can join refused while hosting; the Public search's exact
  filters, its one row and no join; a player who is not the host's Steam friend joining from the list, `wait=` counting
  down, denied then let in, with `sbo_players` following; a friend let in at once; `friends_ask` making a friend wait; a
  Private session shut to joins, with no rows, code or invite dialog, refusing a member Steam let in; what the Public
  tab hides (Friends only, Invitation, another version, full, no rows, match lobby, blocked on Steam or with `coop
  block`, our own) and its order by ping; the Friends tab's walk (a lobby read only once Steam answered, dropped after 5
  s with no answer); the list search's refusals and a match search ending it; the row cleaner; `sbo_ping` waiting for
  Steam's ping location; a new Steam name reaching `sbo_host` within 5 s;

### Poses

- `game_partner_engine_test`: the pose path against fake memory. Its build pin's refusals name the pinned stamp and
  size: a port changes them (see [Porting](porting.md#the-port-step-by-step));
- `game_codec_test`: the codec's round trips, the deltas against a keyframe, a decoder fuzz and a 60 a second stream
  with every second delta dropped, which decodes whole;
- `online_partner_delta_gain_test`: what the sender's delta tolerance (`kTolerance` in `game/codec.h`) saves. With no
  argument, as `tools/install.py` runs it, it encodes two synthetic recordings (idle and running) made by the real
  sender with no tolerance and with it, checks that the tolerance saves bytes on both and prints keyframes, deltas,
  their mean sizes and KiB/s for each. `build/host/online_partner_delta_gain_test path/to/coop-record.bin` measures a
  recording of the current protocol instead;
- `game_table_test`: the component table and the display file, with a parser fuzz, and the per-slot file names
  (`slot_file`);
- `online_partner_resend_test`: our component table's resends (`TableResend` in `game/table.h`) on a worker passing
  every 50 ms: at once to a new friend, then 5, 10, 20, 40 and 60 s apart, every 60 s from then on; a change brings the
  next one 5 s after it and starts the doubling over; a sign her side lost our table brings it within 5 s, and a flood
  of them sends one each 5 s at most;
- `online_partner_record_test`: the recording's reader, with a fuzz, and its replay, with same-place enemies' `SBE` and
  show lines re-stamped on the poses' clock;
- `game_stream_test`: the loopback pipeline in simulated time, and the playback of a match lobby member who gets every
  2nd or 3rd pose of a 60 a second stream (cap 30 or 20): with 100 ms of lag she is drawn 150 or 175 ms back;
- `online_partner_inbox_test`: the game thread's pose inbox (`kInbox` in `game/core.h`) in a full match lobby, 7 members
  sending 60 or 30 poses a second: one game-thread stall of 102, 198, 291 or 361 ms (the stalls of steady play
  in the 2026-11-12 log) drops no pose and leaves no delta without its keyframe;
- `online_partner_gap_test`: the native tick's gap line (`gap_line` in `game/core.h`) from fixed values: the UTC time of
  day out of a FILETIME (the last 100 ns of a day included), the gap in whole ms, a frame past 32 bits, the tick before
  it, and the `vkd3d-proton.cache.write` growth, left out when there is no such file;

### Saves

- `online_saves_watch_test`: the save watcher;
- `game_slot_test`: the slot line, the marker, the save file name's lookup in the game's constant table, its
  switch and the read-only probe, against fake memory, and the title check, which also refuses while SB reloads the
  save (client +0x2f9c) or that flag cannot be read;
- `game_twins_test`: the co-op save copies on a temporary folder: the game's save check, the name check on every
  write (the SBO session record `StellarCoopSBO0N.bin` included), the manifest, the backup before the first copy,
  torn reads and failed writes, the requests and the switch against a fake game (refused during SB's own reload too),
  the plant of a built save as one co-op copy with its mark, and the export's refusal of a planted copy;
- `game_rotation_test`: the per-save copies' folder: the names it accepts (`<UTC>.sav`, `-pre.sav`, `-session.sav`,
  `-replaced.sav`, a `-<n>` after a clash) and every other name refused, a free name on a clash, the drop that keeps
  the 10 newest, spares the open session's two copies, never lists a `-replaced.sav` copy and never lists another
  file, the save queue's fall to 0, a save seen as rewritten by its size or write time, and the copy a restore keeps
  of the file it replaces as `-replaced.sav` (no name when the write fails or reads back different);
- `game_sbo_record_test`: the SBO session record's text and its refusals (another version, an unknown or repeated
  key, a slot outside 0 to 4, an unknown state, a copy name with a folder in it, a line cut short, over 4096 bytes,
  each required key left out, a `pre` or `session` that is not a rotation name), the sidecar's name,
  `NewGameCreateTime` read from a built save and C1's test that it matches the record's, and the write against a fake
  folder: the old sidecar backed up first, then put, and a read-back that differs refused; a missing sidecar reads as a
  closed record; the rotation copy against a fake folder (the oldest past 10 removed only after the copy reads back
  and the sidecar reads, the open record's session copy spared) and the restore (the replaced file kept first, no put
  without it);
- `game_shortcut_test`: `coop shortcut`'s paths and its read of built GVAS bytes (the engine branch, `MapName`,
  `CampAlias` and `DateTime` within their maps, an EVAS header stripped, short and bad bytes), its copies, lines and
  summary;
- `game_shortcut_load_test`: `coop shortcut load`'s cleaning on built GVAS bytes (`SBAchievement` dropped, six
  gears out of `Inventory` and `ItemOtaineSet` with every size fixed, items with no row kept, a gear named anywhere
  else refused, the EVAS wrap and its CRC, the pin, cut bytes refused), then the 15 developer saves themselves when
  the machine holds the research copies under `~/.claude/project-notes/stellar-blade-minecraft/runtime/2026-10-26/`
  (skipped elsewhere): each cleaned and checked, the file without `SBAchievement` byte for byte, with no achievement
  name or gear left and no item missing from the `ItemTable` dump but the seven known ones;

### Night Operation

- `online_modes_nightop_probe_test`: the Night Operation poller's reads, lines and verdict against a fake image;
- `online_modes_nightop_roxanne_test`: Roxanne's and Lily's choice lists in SB's select cache
  (`online/modes/nightop/roxanne.h`) against fake memory laid out like the pinned build: on (our six rows in a GMalloc
  array, the pointer written before the count, her old array never written), off (her pointer, count and max back), a
  second on, an element array moved by a rehash, an entry the game rebuilt, the refusals (no world, no holder, her list
  absent or of another shape, no memory) and the `roxanne=` line; Lily's eight rows taken in the cache's own order
  behind the borrowed row, a row twice, one of another list or one missing refused, and the `lily=` line;
- `online_modes_nightop_guard_text_test`: the Xion guard's 12 text keys and the 23 cultures, a `guardtext` request's
  culture and seven lines into UTF-16 (Korean, the French no-break space, a character outside the BMP) and each refusal,
  what the game thread writes before and after coop off, and the `guardtext=` line;
- `online_modes_nightop_shop_ui_test`: the Night Operation shop screen's guard (`online/modes/nightop/shop_ui.h`: a
  client and its UI manager always, in game and playing for an open only), its answer word's round trip, the
  `nightshop=` line and the log lines;
- `world_teamshop_shop_ui_test`: the team shop screen's guard (`world/teamshop/shop_ui.h`: a client, its UI manager,
  in game and playing), its answer word's round trip, the `teamshopui=` line and the log lines;

### Table rows

- `rows_rows_test`: the Lion's, the Gardener's, the Tendril's, the Shock Bolt's, Matrix XIII's and the Night Operation
  shop's rows against fake memory laid out like the pinned build, each batch over its own module header's patches:
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
    - gun mode's rounds batch (`fight/gunmode/nikke_rows.h`): its 8 RewardGroupTable rows first, then its shop item,
      then the 3 camp ShopTable rows patched in place, last; no ItemTable row, no name or ID another batch holds;
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
    - gun mode's 9 rows added from their templates and its 3 camp shops patched in place, each with its patches as
      written, a later run adding nothing;
  - the refusals that call no AddRow (a missing template, a taken ID or name, a wrong vtable, AddRow slot or row size);
  - a later run skipping the rows already in, FName's number split, the read-back through the game's lookups by ID, the
    answer word, the `lion=`, `gardener=`, `tendril=`, `bolt=`, `mxiii=`, `shop=` and `signal=` status lines and the log
    lines;
- `rows_shock_test`: the Shock Bolt's two lists against fake memory: both gun stances given the two fire commands
  (through the game's grow or inside the capacity), the const ammo list and the slot manager's list given
  `Bullet_Shock`, a second run writing nothing, no slot manager yet, the key found down its hash chain, each refusal
  writing nothing, an allocation that fails, the answer word, the `shock=` line and the log line;

### Shared enemies

- `fight_enemies_engine_test`: the shared enemies' side inside the game, the enemies `fight_chars=auto` picks and leaves
  out, the enemies' state map, the two-player scaling, the vitals read, and same-place enemies' freeze (BlockAI put back
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
  - phase 8's level read (an effect our EVE cast gives its row's HitLevel, found by the ID at `+0x88`, plus her
    AdditiveHitLevel; another caster, a row ID of 0 or no tables give the guess with no latch; the life from `+0x74` in
    every case), the copy's poise and ActorType read each pass, a mirrored flinch of 200 ms started through the context
    call with 0.2 s and 0 while a crowd control goes through the call with no context, its echo never told back, a
    flinch refused on a copy the side draws, the host's `stagger` values on both sides (both off on a guest's side
    before the host's line), `Engine::window`'s refusals (`type`, `state`, `running`, then `full` before any game call)
    and its start of 1001400 with the window in seconds at `+0x0c` and k at `+0x10`, the restore check on SB's effect
    clock (a knockdown inside a window, a 10 s pause, a 60 s freeze counted unchecked, an effect listed past its life
    logged once with windows off for the run), a copy gone or dying before its check skipped with no latch, her poise
    line taken at her owner epoch only and the `fight=` line's `stagger=` field;
  - the PvP test's mode in the worker (a co-op save and a linked friend, never beside the shared fight either way, her
    pvp lines alone reaching the job with her SteamID, its own sent reliable, no restart at a host change, a pause and a
    new session when her link drops and comes back, `coop pvp off`);
- `game_fight_sync_test`:
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
  - phase 8's lines (the five-field cc line with the hit's level and the reaction's time, the three-field form refused;
    the stagger and poise lines with their bounds; a recording keeps stagger, never poise) and their rules: the stagger
    line after bosses while either setting is on and again at each change, both read as off on the guest's side until it
    comes and after the host's next world; Rule A on both sides (a mirrored crowd control under the copy's poise refused
    and counted, a copy with an unread poise refused, a level that could not be read sent as the guess and counted); the
    flinch mirror (told from no reaction with its time, its chain and its echo not told, refused while the copy holds a
    reaction, under its poise, with `hit_reactions` off or on a drawn copy (one the pilot does not draw takes it), a
    knockdown still started on a copy that only flinches, a flinch line never replacing a crowd control still waiting);
    Rule B (no window for one player, k 1 for a Monster and 2 for a boss, a refusal counted and logged once every 10 s,
    the owner's poise line taken at its epoch only and stale otherwise, windows with no poise line on a copy the pilot
    does not draw, nothing new with `stagger_resist` off or on the guest's side before the host's stagger line, a cc
    line refused on our copy still counting the other player, her reactions forgotten at her off and on, the host's at
    its world line),
  - and two fake worlds linked through a delayed, lossy line;
- `game_poise_test`: phase 8's rules in `game/poise.h`: the level compare (HitLevel plus the additive level cut toward
  zero, a NaN poise and an additive that is not finite refused), k by ActorType, the reaction's life in ms (10 s at
  most), the window's length (none for one player, 1.5 s for each extra player, 6 s more at most), the context bytes
  (`+0x0c` and `+0x10` written, every other byte of SB's init left as it was), the players who made each enemy react
  within 10 s by slot, one window a copy until its check settles and `full()` before any game call, the restore
  verdict on SB's effect clock (wait until 0.5 s after the end, done once unlisted, failed when listed 0.5 s past its
  life, unchecked 60 s after the end or on a NaN) and the quiet log (one line for each enemy, what and why every 10 s);
- `game_spawn_sync_test`: the core of same spawns (stage 4):
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
- `game_pilot_test`: the core of same-place enemies (stages 3a to 3c):
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

- `game_pvp_test`: the PvP test's bounds: the cap per named move (the victim's attack and critical damage, the move's
  AttackDamageRate, 1.2 and a margin of 2, at most 10,000,000), a sender outside the members, the range, a move with no
  cap, d clamped to its cap and to half the victim's MaxHP a second per attacker, 60 lines a second per attacker, and
  the windows of members who leave and come back;
- `fight_enemies_engine_test`, the attacker's side: no stand-in before her ghost is drawn, one `M_DummyA` from
  `NewActor` at her feet plus 97 cm with no spawn key, BlockAI_Infinite, Off_Hud, DisableMonsterWarp and
  Passive_Immortal in that order with itself as caster, its MaxShield set to 0 once with NoDamage passed (its Shield
  goes with it, with no shield break), each drop healed at the next turn and sent naming our EVE's skill (or one seen
  within 1 s; else unnamed), a hit past its HP held at 1 by Immortal and never a death, no move for 3 cm, one for 10 cm
  and none while her ghost is not drawn, a stand-in the map lost made again, three tries 5 s apart when SB refuses
  BlockAI, and the despawn at the end;
- `fight_enemies_engine_test`, the victim's side: a MinimumHP floor of 1 on her EVE for the session and off at its end,
  each line through ApplyStat on her EVE with no cause, the HP number and NoDamage not passed, the cap per named move
  (252 for LightAttack1_1 with attack 100 and critical damage 1.5), her dodge (state 3) refusing it in the game with the
  state logged, half her MaxHP a second, a stranger, a skill with no row, her ghost 20 m away or not drawn; her own load
  mid-session (a line with no EVE refused and nothing written on the old actor, the floor and the hits on her new EVE);
  and two worlds, where a 60 HP drop of the stand-in in one game takes 60 HP from the other's EVE;

### Other native headers

- `online_photo_photo_freeze_test`: the synced photo mode's pause against a fake pause set;
- `game_globals_test`: SB's globals as build 26123051 lays them out, checked at compile time: the block offsets the
  fight engine, the photo freeze, the lion gate and the Night Operation probe read land on the registry, the world,
  logic and the net-mode cache. Every header that names one of these globals by address names the same one. A port
  writes the new build's addresses there (see [Porting](porting.md#the-port-step-by-step));
- `eve_debug_keys_test`: `coop fly`'s and `coop slowmo`'s gates against fake memory laid out like the pinned build: the
  keys' hash, the lookup through inline and allocated buckets and along a chain of collisions, each refusal with no
  write, and the passes (a gate set with its old value kept, set again after the game built its map again, its old
  value back once unwanted, nothing read while neither gate is wanted or ours); the worker's side: no gate wanted off
  a co-op save, slow motion only with no friend linked, the asks cleared by `off`, a Lua load and a refusal, and a
  gate's state logged from the first pass that read its ask, never from an earlier one; the level flight's hold: the
  flight key set again only while the controller's pawn flies with none held, never after a press of the jump key
  in that flight until it ends (a jump key held from before the flight counts only once let go and pressed again);
- `game_anim_test`: `coop emote`'s native clips: the clip paths that pass, the game's string built from one, the call's
  arguments, the custom animation slot as read, and the track (a play answered with or without an id, the watch on
  our clip, another clip, a cleared slot, a gone EVE and a slot that takes no weight, with paused time left out,
  the stops, the fault, the status word and the log lines), our EVE as the controller's pawn and the check that she
  is still the object played on, over fake memory (no pawn, a pawn of another class, a pending kill, a new serial),
  what each frame does; the bike's `ride` play (a loop forever with foot IK type 2) and its foot IK put back as SB's
  stop does once the ride's play is over;
- `game_bike_test`: the bike's native side (`game/bike.h`): the preload path rule, the 54 gated names, the gate over a
  fake action map (each state kept and put back, an absent name back as on, a name SB changed during the ride left as SB
  set it, a name the game never made skipped, a controller gone, a fault in the middle of turning it on, a fault), the
  words packed for the worker and the status line, the ride plays' clip lookups and the log lines;
- `game_keep_test`: the keep (`game/keep.h`): the path rule (object and class paths under `/Game/` and `/Engine/`),
  its list of paths each asked once, at most 128, the batches and the counts, the lines of `coop-keep.txt` (70 at
  once, the same text again adding nothing, a bad line counted) and the status field;
- `game_theater_test`: SB's theater read (`game/theater.h`) over fake memory: no theater, one loading its first take,
  one playing with its sequence named, another listener or none, a finished one, another image base; the field's text;
- `world_daynight_sky_test`: the day and night cycle (`world/daynight/sky.h`): the clock at :02, :12, :32 and :52 and
  under 24 just before the hour's wrap, the ramps, the sun and moon at noon, sunrise, sunset, midnight and mid-morning,
  the dusk colour, the status line. Over a fake WorldSettings whose env array holds a sunlit element with its own
  exposure bias, a covered one and a sunlit one without the bias bit: noon and midnight written from the originals with
  the covered one given only the direction; a restore; a copy SB makes into an element; another world at the same
  addresses, read as new; SB's forced settings (nothing written, a restore still puts the array back); the gated blend,
  too many elements, no world, an empty array; a pinned hour, a hold that keeps a pinned hour or the clock's; an element
  SB moved in its array keeps its originals; the array watch (a changed count or pointer seen until the next pass, a
  forced pass clearing it too); the overlay's count; a hold released, a pinned hour changed and a second change during
  a glide moving each value over 2000 ms with no step above a frame's share; an off during a glide putting the
  originals back; the direction a unit vector through the moon's swap; the light the status line prints during a
  glide; a new world, a clock that steps back and an element that comes during a glide; a glide with no element; a
  change under SB's forced settings gliding once they end, a forced pass stopping a running glide; a change drawn at
  once in a world no pass drew in yet; a waiting array stopping a running glide;
- `cutmenus_items_test`: `coop gift`'s inventory read against a fake image laid out like the pinned build: the FName and
  CityHash64 hashes checked against the game's, a count over two instances and along chains of collisions, an item
  EVE does not carry, no manager, bucket or owner, an instance the manager no longer holds, and hostile memory (a
  chain that loops, an index past the array, a hash size that is no power of two, an unreadable item) ending in
  `unread`, never in a hang;
- `ui_pad_test`: the controller's events for the co-op menu (each press, up and down repeating while held, a D-pad
  diagonal read as up or down and the stick along its main axis, which keeps its pressed axis near 45 degrees, the
  stick's thresholds, View held 1 s, D-pad Right held 1 s for the bike, LB, RB and Y once a press and in event order
  with up's repeat going on, a disconnect, the event queue), which XInput slots each poll asks, `PadKeys` (a held
  button in every read until its release, a press and release inside one poll counted once, a repeat ignored, two
  controllers ORed, the stick pushed furthest, clamped values, unknown keys and ids outside 0 to 7 ignored, `clear()`,
  the events from `PadKeys` as from XInput), Slate's handler slots pinned to the vtable and the Online tab's event
  posted into the queue in order with the pad's, a full queue dropping the newest;
- `ui_pause_tab_test`: the Online tab's decision on the GameMenu logic's input (RB on the highest enabled tab while the
  game's tab lock is off opens it; any other tab, action or lock passes the action on to the game; a tab list the game
  never builds passes too; a press and its release within 500 ms open once) and its pinned slot, function, FName
  global and offsets, the game's own close of the pause menu with the logic's vtable, type and entry offset, the
  answers Lua reads from `coop_pause_close`;
- `online_session_options_test`: the game's Tutorial and RecordPopup options during online play (an option On at link
  forced Off with On kept, the save slot handed the kept value while it is forced, the value back at unlink; an option
  already Off left alone; the player's On during online play kept with no new force until unlink; a value the game never
  writes never forced), the pass over both options with its fault latch (a fault in the second option's lookup right
  after the first one's force, or inside SetValue, leaving that option shown forced so the save slots stay held; the
  next pass putting it back though online play still asks the popups off; a second fault stopping the pass with the
  option still shown forced; a first fault with nothing forced running no more passes), their pinned keys, vtables and
  save slots, the registry lookup over a fake map (on the heap and inline buckets, a key further along its chain, an
  empty map, no bucket, an index out of range, a chain that loops, a read that fails) ending in 0, never in a hang;
- `game_dev_panels_test`: `coop devinfo`'s guard (each read failing alone, refused with its own reason; a close needs
  neither the flow nor the phase), the plan over every mix of open panels and every ask (the other panel closes, the
  one asked opens unless it is open), and the two panels' logic types and names;
- `game_travel_test`: the follow's fast travel request, its bytes at each offset, each guard refusing with its own
  reason (a respawn in flight included), the call count (three calls in 10 s, a 10 s wait after an accepted call, none
  after a refused one) and the watch over the warp block (pending, warping, arrived, a block cleared before it ran, and
  one that never ran: stuck);
- `game_sbo_test`: the SBO lobby's Join match, record states, why words and status line; the entry's guard in order, one
  entry at a time (`busy`, also while this run's warp still loads) and none while the slot's record is open (`record`),
  the save wait and its 30 s limit, the saved-file checks, the warp's guard, the arrival watch and its 60 s limit; the
  return's guard, the restore rule, the reload watch, SB's own reloads, the title recovery and the load of an open slot;
  `seq_pick`, which lets `coop sbo seq` run only one of the four sequence names the native part made; the New Game+
  read's pins (0x1470373c8 and `+0xe4`) and `cycle_ok`, which keeps counts 0 to 99 and difficulties 0 to 2;
- `online_lobby_preset_test`: the match loadout's call order, the slots it empties, refusals and read-back;
- `online_group_region_tabs_test`: the teleport screen's record list: the sanity check, the name lookup, the append.
- `online_lobby_loading_test`: the lift of the lobby arrival's black over a copy of SB's auto list: each entry of tag 5
  gets lifetime 0, SB's own entries and every other byte stay as they were, and a count out of range touches nothing;
- `game_camp_text_test`: Matrix XIII's camp names and the 25 records' words, the keys (unique, the region's ending in a
  letter), the pick of one of the 23 cultures, when a pass is due and the `camptext=` and `recordtext=` lines;
- `game_camps_test`: the activated camps' read, each guard refusing with its own reason (a warp, a respawn or a logic
  task as busy), when the list is read (at once with none held, in a new world or after a drop, then every 2 s) and
  the `activated=` line (the list, the camp EVE respawns at, a refusal, names that would not split left out);
- `link_pak_list_test`: the `.pak` mod list's filter and digest (the base game's files left out, mods in any folder and
  any case counted, the listing's order and a name's case changing nothing, a size or a name changing the hash), the
  containers by name, the names as they go to the friend, hers against ours, the status list, and the CNS packs
  under `~mods` with their outfits and the `/Game` assets they declare (comments, other keys and a text cut short
  included), a `.utoc` directory index read into object paths (maps, other roots, encrypted, unindexed, cut short
  and looped indexes refused) and the shared list of containers both players have;

### Shared world

- `game_objects_rows_test`: `game/objects/rows.h`'s lists strictly sorted (each zone's saved envs by zone, then
  alias), every SetEnvActive and no-progress row with states of its own, the lookups at both ends of each list and on
  near misses. Rows of build 26123051 each rule keeps or leaves out (a door and a lift with every state, the
  monorail without its camp-bound garage run, the crane without its camera states but with its CallPuzzle, the
  hyperdrive without its story states, a supply box, the boss cores, a story-only door, an env whose On a quest task
  waits for, a Matrix XIII lever, a counter whose progress leads to an item, a quest's env control row, a monorail
  speed row whose chain plays a scene). Then the 40 states that a map-progress achievement or a hint completion held
  out before, the passcode doors and the other states that stay out, the trap floor's end as the one watched pair.
  Each zone's saved envs: the largest zones' counts, no entry under None, the pipe puzzle's water gate, a tag kept as
  the table spells it, the InitActivate None entry and the rows each rule leaves out (ResetZone, SaveType None,
  SaveWithTransform, InitStateTag None or none of the row's states);
- `game_objects_sync_test`: `game/objects/sync.h`'s lines through format and parse and back (the largest legal line, 50
  malformed lines and 20,000 fuzzed ones), the ring's capacity and wrap, the outbox that keeps the lines the link
  refuses, and two players' sides wired over the parser with a fake engine: the on and off lines and the answer to an
  on, a rejoin one side did not see, each gate on both sides, the lists on both sides (linked env lines part by part
  included), names without text, sequence numbers, lost and old lines, a load that reads no save for a while, the
  queue's order while loading and its overflow, the apply limit, the echo backstop, refusals logged once, a new partner
  and the status line. Then names compared without case, the catch-up lines through format and parse (17 malformed
  ones) and on the lists, the watcher of the trap floor's end (its silent first sight, only live reads counted, its
  tags kept through a load and a stream, forgotten at a zone change, a close or a new partner, its line on the gates
  and the shared `seq`) and when an env counts as touched. The catch-up by zone: the ask after its 2 s hold and again
  after a load, her `on` or a close of our side, the walk and its resume after a load, an ask for a zone with no entry,
  the receiver rule for host and guest (a state held out for us kept, nothing sent back), a `c` line older than a root
  of ours kept (her answer or her send-back), a `c` line applied as a state then an Enable or Disable, the host's value
  sent back, a close in the middle of an answer, the walk's filters, one answer per ask, the ObjectState compare and a
  partner that never answers;
- `game_objects_engine_test`: `game/objects/engine.h` over fake memory and fake game functions: the four roots read from
  their nodes (a named target, `self` through the owner env, an ObjectState of 0, a linked env inside and outside its
  owner's list or not live in our zone, values no line carries), and her lines applied: A1 and each of its guards, a
  Disable env changed as SB changes it, a tag that did not take, A2's records (found, made, a Disable one written), A1b
  live and offline, A3's call and its list check, A4's order (a None tag, an env already in the tag, a refusing guard),
  and the refusals for a missing world, player or name. Then the catch-up reads: an env's value live, from its record
  (a wrong vtable read as not live) or not at all (no world, a zone or an alias the game lacks), an ObjectState no line
  carries read as 0, a tag with no text read as none, no record made; the client's zone, refused for None, a name
  with no text or no client.

### Story together

- `game_story_rows_test`: `game/story/rows.h`'s lists sorted (scenes by path, trips by row), the lookups at both ends
  and on near misses, rows of build 26123051: the camp talk six rows share (told apart by priority, then by zone, then
  by table order), the Pod landing scene whose end warps the player, a two-event end chain, a shared quest's subtitle
  sequence, a row whose condition is tested before the call, Lily's warp (sent), the lift's zone change (not sent) and
  the trips left out.
- `game_story_sync_test`: `game/story/sync.h`'s lines through format and parse and back (the largest legal line, 67
  malformed lines and 20,000 fuzzed ones, the hooks an on line carries, an InputCounter line's last bit), the lists, the
  leash, the dialogue release, the story gate and the replay guard on their own. Then a host and a guest wired over the
  parser with a fake game on her side: the on and off lines with the host's hooks kept as `partner_hooks()`, a scene
  started and shared, the leash holding her and letting her go, results applied once in their take, dropped once her
  copy left it and applied again when her copy comes back to that take, a widget that comes late, a result her game
  refuses, her dialogue wait closed once, a skip, the host's end with her copy played out, the replay guard and its
  expiry, a first take that differs, a scene that never shows, a refused start, a busy game, a second start while her
  copy still starts, an attach, a quest row, a talk, trips that wait for her copy, the host's position rate, sequence
  numbers, the queue while she loads and its overflow, a new partner, the feature off, her save not a co-op save and the
  status line. The host's choice and QTE results go before his skip, his position and the end of a theater they closed
  in; those of a play he does not share are logged once.
- `game_story_engine_test`: `game/story/engine.h` over fake memory and fake SB functions. Host side: his theater, hook
  1's read, his menus read when they close (a menu of another play left out, ordinals counted by take), his QTE and
  InputCounter blocks read once final (Flow results as bits, a widget read before its next start, a Flow's results then
  kept from the last pass, the bit that says his take skip ran, set by his latch or by his take ending before that read,
  one gone, one he did not lead), hook 4's trip line (a row that is no trip, a zone that cannot be read). Guest side:
  her copy and the gate's reads, a play and a talk started, a trip run with her ID, the host's seek and take skips, the
  leash, her dialogue closed, her skip blocked and given back, a choice line stored in her take context (a name or alias
  she lacks refused) with her menu for it closed after its skip latch is taken, her PlayerChoice answered through her
  OK, her QTE and InputCounter given the host's values (late, gone, a success that finishes at once, its take skip only
  after his, Flow results), her presses taken when a block starts and her menus held then given back.

### Quests

- `game_quests_sync_test`: the shared quests' quest table (its kill and item tasks), line format and parser (with a
  fuzz), the host's and the guest's rules, the zone marks, the item hold, the steps made together and those that are
  not, the record file, lost lines and reloads; a step the guest makes first: sent only from the host's line in his
  zone, sent at a later pass when the line rate refused it, not sent while the host is off, never echoed back, taken by
  the host under each rule of `accept()` (two tasks of one group done on both sides in one pass end with both in both
  games), the host's checks on her step lines (one from the same line again taken, an older one dropped);
- `game_quests_engine_test`: the shared quests against a fake quest unit: the walk, the guards before each game call,
  the gate, a fault, two PCs through channel 2's text with delay and loss (her step made first taken by the host's game,
  kept through a hold of his game until 16 wait, the same step again made once, dropped by his load), three PCs (one
  read of the host's quests a pass feeding a Host per guest, each guest's own snapshot and lines, the pair's step made
  once in the host's game and brought to the second guest, the second guest's step line dropped by the host, none sent
  once she is told she is no pair (`Engine::pair`), the status per guest, her quest then ahead with the host's ahead
  note naming her, the host's state naming the first guest on (`with=`), a guest who leaves losing her Host only while
  the record keeps her lines, her return with our on to her alone and a snapshot of her quests only), a recording
  replayed into another save, the worker's side (the gates that start and end a side, channel 2's lines beside the
  fight's, the record file and the status lines), the worker on a host with two guests (each guest's on and snapshot,
  each guest's lines to the engine under her own SteamID, the second guest's step dropped and the pair's taken, another
  member's line never reaching a guest's engine, the pair gone with pair 0 while the second guest stays, the left guest
  logged under her own SteamID);
- `story_quests_own_test`: the mod's own quests in a fake quest unit (`story/quests/own.h`): nothing read off a co-op
  save, on SB's logic thread or before the world and the manager exist; the ID map through its inline and heap bits; the
  prologue and Quest_Epic_11 read beside "On Time"; each request word's one call (an acquire once, never when held; a
  first task's Complete only at that word's group with its task in progress, through SB's Complete and no other
  address); the answer word (every field through it, a value out of its 4 bits read as -1) and the `signalquest=` line.

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
- `sbo_lobby_rows_test.py`: `tools/sbo_lobby_rows.py`'s two outputs, `online/lobby/sbo_maps.lua` and
  `online/lobby/halls_rows.h`, match `data/sbo-lobby.json`, the module loads in Lua, the halls batch holds one seat row
  per kept seat but the camp ones (unique names that never end in `_<digits>`, unique IDs above build 26123051's
  highest), and its checks refuse bad spots, seats, names, IDs, fences and a batch of more than 255 rows. After a change
  to the data file, run `python3 tools/sbo_lobby_rows.py` and commit the two files it writes;
- `teamshop_rows_test.py`: `tools/teamshop_rows.py`'s two outputs, `world/teamshop/teamshop_rows.h` and
  `world/teamshop/rows.lua`, match `data/teamshop/`, the Lua file loads in Lua, the batch holds every ItemTable row,
  then every ShopItemTable row, then the ShopTable row `SBOTeam_Shop` with no tag, which lists each `_Buy` row once.
  Each `_Buy` row sells an item of the batch for gold with no gate field. Its checks refuse an alias without the
  `SBOTeam_` prefix, an ID range at or under the highest ID the game or the lion, bolt and shop batches hold, two
  owners with the same name, alias or overlapping ranges, a field off the allow-list, non-ASCII text, a NanoSuit the
  shop screen would sell twice (`MaxAmount` above 1, an `InventoryAlias` or a `MaxAmountOverrideActorStat`), an
  unread donor, a price other than one gold price from 1 to 999999, a batch of 256 rows and a range too small for its
  items. After a change to a data file, run `python3 tools/teamshop_rows.py` and commit the two files it writes;
- `world_rows_test.py`: `tools/world_rows.py` on small made-up tables: each rule that keeps a ZoneEnvSpawnTable row
  out, each rule that keeps a state out (the player event types reached directly, through AddEvents and FinishEvents,
  through the states an env control row sets and through a progress control's change tags; the crane's camera tags;
  ChangeState achievements and EnvState quest tasks on the state or on a state its events set; a map-progress
  achievement and a hint completion that hold nothing out, an album or loot achievement that does), the SetEnvActive
  list, each ZoneEvent rule, the no-progress list, the watched pairs (a trigger's own TriggerTrueEvents or its env
  row's, a ResetZone row, a pair set only through a state cascade, a pair set by an env that is no trigger), each
  zone's saved envs (one entry per zone, None left out, an InitStateTag compared without case, an InitActivate Disable
  or None; an InitStateTag None or none of the row's states, ResetZone, None and SaveWithTransform rows and loot left
  out), unknown names and loops in chains, Matrix XIII's rows from its data file, the written block (sorted, between
  its markers, the rest of the header untouched, a name that cannot go into a C++ literal refused). After new table
  exports, run `python3 -I tools/world_rows.py <folder>` and commit `native/src/game/objects/rows.h`;
- `story_rows_test.py`: `tools/story_rows.py` on small made-up tables: the quest events read from a quest table block,
  the zone a row's name gives, each scene rule (a theater path, a level sequence alone, Stop rows, rows with no theater
  row or no path, the priority as the theater manager keeps it, the condition kept only beside AddEvents, the quest
  flag, the order), the ambiguity counts, each trip rule (camp and spawn point targets, a ChangeZone, no target, a test
  world by name and by target, the cut multiplayer warp) with every starter letter, the written block (parsed back
  to the same values, lines within 116 columns, between its markers, the rest of the header untouched, a name that
  cannot go into a C++ literal refused). After new table exports or a new quest table, run
  `python3 -I tools/story_rows.py <folder>` and commit `native/src/game/story/rows.h`;
- `modules_test.py`: the rules that keep the modules apart ([Structure](structure.md#the-checks)): `MODULES` names
  exactly the folders with a `wiring.lua`, each with its `off_test`; no `needs`; no module's file or test requires,
  fakes or patches another module's file; every late read is in `uses`; each export is set by one module; each build
  step is built once; each hook callback checks `M.off_modules`; no native file of a module reads another module's
  header or part (a module's folder is its longest path, so `online/lobby/` and `online/session/` are two modules);
  each language table names the modules of `MODULES`. It first runs on planted trees, one fault each, so no rule passes
  vacuously;
- `row_copies_test.py`: the checks between two modules' row files, which no module test may make. The generated copies
  equal their sources: `eve/chainspin_rows.lua`'s `CHAINSPIN` is the ChainSpin rows of `fight/bosses/lion_rows.lua`'s
  `ROWS` in order (with the EffectTable row `P_Eve_Tachy_Skill_ChainSpin1_Use`),
  `world/maps/matrix13/level/boss_rows.lua`'s `ROWS` and `GARDENER` are `fight/bosses/lion_rows.lua`'s. The Night
  Operation shop's cut items are ItemTable rows of the lion batch, or of the bolt batch for the Shock Bolt;
- `matchmaking_scan_test.py`: a scan that fails if any script or native source could reach the game's matchmaking (see
  [online/modes/nightop-previews.md](../online/modes/nightop-previews.md#how-the-original-matchmaking-is-blocked)).
  Score attack's `online/modes/scoreattack/run.lua` holds one guarded `CreateSBZoneEvent` (the heal row only), its
  one `ServerRequest_CreateActor` and its one `ServerRequest_ActorRespawn`: a plant that widens the guard, removes the
  file's guard or adds another request (`ServerRequest_ActorRevival`) fails the scan.
  Stellar Blade's RunZoneEvent address is held once in `native/src/game/sbo.h` and called at two sites: once in
  `native/src/online/lobby/sbo_game.inc` for `coop sbo seq`, and once in `native/src/glue/tick/world_game_shared.inc`.
  That second site serves the shared world's env control rows, which `game/objects/engine.h` checks against
  `game/objects/rows.h`'s list right before the call. It also serves story together's scene starts and trips
  (`game/story/engine.h`), whose rows are on `game/story/rows.h`'s lists (`scene_row()`, `trip_sent()`);
- `sbo_difficulty_scan_test.py`: a scan that fails unless `native/src` calls Stellar Blade's difficulty setter
  (`sbo::kSetDifficulty`, 0x141cf3180) exactly once, in R8 after the return's reload. Called in game outside a
  Boss Challenge zone, the setter makes the game reload the save, and on 2026-11-12 the call the SBO lobby's entry made
  right after its warp did that and sent the player back to the saved spot;
- `port_addresses_test.py`: `tools/port/addresses.py` on a fake source file (addresses in comments, strings and raw
  strings left out; constants, tables, struct fields in a table, `Rva` constants and digit separators read), then on
  `native/src`: every game address the code uses has an entry in `tools/port/signatures.json`, every entry is used
  and each has a known kind (see [Porting](porting.md));
- `port_signatures_test.py`: `tools/port/make_signatures.py`'s instruction decoder on 38 instructions checked against
  capstone (rel32 calls and jumps, RIP-relative operands with and without an immediate after them, SIB, VEX, EVEX,
  prefixes) and its refusal of an opcode 64-bit code does not use; then each kind of signature on a PE file the test
  builds: a function's own run, a code address, a call into one of two identical functions, a load followed by an
  immediate, a vtable slot found through its vtable's start, a function only a vtable slot points to (`read`), a
  global loaded in identical copies of a function (`then`), a global whose load is found by a run that starts at
  the instruction before it and a vtable no code loads (`holder`, past a slot whose code another place also holds).
  Bytes inside an instruction that read as a call give no reference. A run stops after a jump out of the code
  section. A signature that matches twice gives no address. A holder whose code two places hold gives no address. An
  executable other than the pinned build is refused. Every entry of `tools/port/signatures.json` that needs a
  signature has one in the form the tool writes, with the names the code gives its address. Then
  `tools/port/find.py` on the same PE file: every entry is found, the image base and a section included. With a
  function added before the others, the code addresses move by 16 bytes and the data addresses stay. Three copies of
  a function give `ambiguous (3 matches)`. A holder's code held in two places gives `ambiguous (2 matches)`. A
  function removed gives `missing`. So does a `read` that lands outside the file. The exit code is 1 for each.
  Last, `find.py` on `~/Ghidra/stellar-blade/input/26123051/SB-Win64-Shipping.exe`, Ghidra's copy of build 26123051:
  every entry is found at its own address. A PC without that file skips this part and says so. A port points `EXE` at
  the new build's copy (see [Porting](porting.md#the-port-step-by-step));
- `release_test.py`: `tools/release.py`'s build, upload and publish steps and its refusals, with git, gh and
  `tools/install.py` faked;
- `save_read_test.py`: `tools/save_read.py` on GVAS bodies built in the test (the header, values, containers, the EVAS
  wrapper's checks, the byte-or-name guess, value paths) and its commands on saves in a temporary folder;
- `story_lines_test.py`: `tools/story_lines.py` on an invented 29-line example with a known digest, on
  `story_case.json` against `story_case.txt`, on what must leave the digest alone, and its commands on saves and dump
  files in a temporary folder. It also checks `float_repr.txt`, Python's `repr` of 2,331 doubles for the Lua side;
  `python3 tests/tools/story_lines_test.py --write` writes it again;
- `windows_test.py`: `install_test.py`, `save_guard_test.py` and `story_lines_test.py` in a Python set up as on Windows:
  text files and subprocess text in cp1252, `\n` written as CRLF and no `signal.alarm`. Symbolic links are first
  refused with WinError 1314 (Windows without Developer Mode), then allowed. Without them, `install_test.py` and
  `save_guard_test.py` print a `not tested` line for each check they skip. Paths keep the separators of the machine
  that runs it.
