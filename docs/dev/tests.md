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

`tools/install.py` runs the tests side by side, as many at once as half the CPUs it may use. `STELLAR_JOBS=1` runs
them one at a time. Each test's output is written in the tests' own order. The first failure writes its output and
stops the run. A native test is built again only when its source, a file it includes, the compiler or its flags
changed. It is run every time.

On Windows, `.gitattributes` keeps LF line ends in the checkout: several tests compare file text with LF patterns. A
clone made before that file keeps its CRLF files. With no uncommitted changes, `git rm -r -q --cached .` then
`git reset -q --hard` checks every file out again with LF ends.

## Lua tests

The Lua tests (`vehicles/bike/`: `drive`, `drive_model`, `fetch`, `model`, `off`, `others`, `park`, `ride`, `rig`,
`stand`; `core/`: `actors`, `actors_of`, `class_at`, `effect`, `enemy`, `items`, `keep`, `keybind`, `line`, `link`,
`mask`, `pak_gate`, `picks`, `player`, `row_edit`, `settings_file`, `ue4ss_settings`, `unreal`, `where`, `worlds`;
`fight/bosses/`: `enemy`, `gardener`, `leviathan`, `lion`, `off`, `tendril`; `eve/`: `chainspin`, `emote`, `flight`,
`glide`, `off`, `wear`;
`closet/`: `closet`, `cns_import`, `fits`, `manifest`, `off`, `resolver`, `slots`; `cutmenus/`: `devmenu`, `mailbox`, `off`;
`story/scenes/`: `lines`, `off`, `scene`; `fight/enemies/`: `off`, `wiring`, `wiring_notices`; `online/group/`: `group`,
`off`, `region_tabs`, `travel`; `online/lobby/`: `arrival`, `commands`,
`halls_rows`, `off`, `sbo`, `wiring`; `online/lobby/ui/`: `lobby`, `lobby_model`; `main/`: `bike`, `boot`, `collide`,
`fishing`, `guide`, `gun`, `idle`, `input`, `keep`, `loader`, `match`, `menu`, `pass`, `photohunt`, `race_match`,
`scoreattack`, `session_ui`, `settings`;
`world/maps/matrix13/`:
`off`, `words`;
`world/maps/matrix13/quest/`: `on_time`, `subtitles`, `zone_talks`; `world/maps/matrix13/talks/`: `zones`;
`world/maps/matrix13/level/`: `boss`, `breakables`, `drone`, `fans`, `mila`, `move`, `travel`;
`world/maps/sboxion/`: `engine`, `off`, `recover`, `rows`, `sboxion`, `tetrapod`, `title`, `world`;
`world/maps/sboxion/rooms/`: `list`, `rooms`;
`online/modes/nightop/`:
`board`, `challenges`, `guard_text`, `off`, `probe`, `recruiter`, `recruiter_text`, `roxanne`, `run`, `shop`, `waves`;
`online/partner/`: `assets`, `bench`, `bike_part`, `capture`, `commands`, `doro_pick`, `ghosts`, `hud`, `off`, `puppet`,
`sentinel`; `online/photo/`: `off`; `story/quests/`: `off`, `wiring`; `online/modes/race/`: `commands`, `doro`,
`drive`, `drive_model`, `model`, `off`, `run`; `online/modes/race/match/`: `game`, `model`, `round`;
`online/modes/race/ui/`: `hud`; `online/modes/scoreattack/`: `board`, `challenges`, `game`, `model`, `off`, `round`,
`run`, `scoreattack`, `waves`; `online/modes/fishing/`: `board`, `fishing`, `game`, `model`, `off`, `records`, `round`;
`online/modes/photohunt/`: `board`, `game`, `model`, `off`, `photohunt`, `records`, `round`, `targets`;
`online/saves/`: `off`, `saves`; `online/session/`: `booth`, `chat`, `commands`, `join`, `off`,
`wiring_cycle`, `wiring_dlc`; `online/session/ui/`: `create`, `create_model`, `sessions`, `sessions_model`;
`world/daynight/`: `daynight`, `off`, `rule`, `wiring`; `story/together/`: `off`, `snapshot`, `wiring`, `wiring_dump`;
`ui/`: `text`; `ui/kit/`: `guide`, `hud_parts`, `kit`, `model`, `notice`, `pause_tab`; `ui/text/`: `culture`;
`world/objects/`: `off`, `wiring`;
`fight/gunmode/`: `aimrot`, `dpad`, `g1_gates`, `helpers`, `ik_pin`, `input_memo`, `laser`, `morph`, `nikke`,
`off`, `release`, `rifle_frame`, `texts`, `v4_rules`)
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
- `fight/gunmode/helpers_test` covers gun mode's pure parts: its settings as `fight/gunmode/config.lua` parses them
  (the defaults with no file, the last line winning, names in any case, a BOM and CRLF, bad values refused), the polled
  keys' edges and a tap against a hold, the crosshair point in EVE's frame and back to the world, the rounds' spread
  (within `gun_spread` degrees of the reticle point, the edge at that angle, 0 for none, the setting from 0 to 10, both
  writes of a round's destination in `mode.lua` going through it), the rifle's magazine
  (a round per cool time, the reload when empty, none when lowered part-spent, the HUD count, no round once the spares
  are spent, a refill) and the one zone event gun mode may fire. That event is kind 2 on the shot's row. Every other kind
  or row is refused. `mode.lua` calls `CreateSBZoneEvent` once, inside the guarded `zone_event`. `fire_row` reaches it
  only through that guard. Over fake tables, `fight/gunmode/data.lua` sets the NIKKE round's `DestTarget` from the
  shipped 3 (`StartToDestDirection`) to 0 (`MainActor`) while the rifle is out, logs the change and gives 3 back at
  `put_back()`;
- `fight/gunmode/dpad_test` covers the HUD entry's glyph (`fight/gunmode/ui/dpad.lua`): the Right twin of the Xbox or
  PlayStation D-pad glyph the game shows, or the `gun_key` keyboard icon for a keyboard glyph. An unknown or missing
  glyph gives none. Over a fake UMG the real entry puts the G icon on the marker's own key cell (`btn`). With no such
  cell it shows no cell at all, since an image with no brush draws a white square. The cell also stays hidden while
  the marker's up button has no texture. An entry built again in a new HUD gets the G icon, the cell, the sizes and
  the place in the same tick;
- `fight/gunmode/v4_rules_test` covers the layer clip choice (hip fire raises the rifle, a ground move carries it,
  the flip keeps the aim), the aimed reload on the aim's pose, the aim bridge through a dodge, her body tilt, the aim
  clip by rifle pitch, the recoil, the hip-fire turn, the comeback after an interaction, the chest turn's ease back (a
  zero turn given back as the same table) and gun mode's own shots, one round each. The player's reload keeps the
  magazine's rounds and tops it up from the spares;
- `fight/gunmode/aimrot_test`, `ik_pin_test`, `morph_test`, `rifle_frame_test`, `laser_test`, `input_memo_test` and
  `g1_gates_test` cover the chest-turn loop, the v4 left-hand pin, the rifle's arrival and departure timing, the
  rifle's frame and its morph scale, the laser's start (0.12 s on target, 0.6 s off it, the rifle not turned on the
  rifle layer), the laser end sent only when it moved, one key read a frame and the G1 gates;
- `fight/gunmode/texts_test` holds gun mode's texts to its code and scripts. The rifle layer's pak has one name, the
  one its build script writes (`zNGMSpike_P`), with the class `fight/gunmode/overlay.lua` looks for: no other pak or
  layer name in gun mode's code, tools, page or NOTICE section. The page and NOTICE name both. NOTICE names Mixamo.
  Each script in `tools/gunmode` starts with the SBO license lines. Its comments name no script that is not there and
  hold no session notes. The Blender and Unreal scripts stop without `NGM_TOOLS` and import into no shipped game folder.
  `export_stand.py` opens by default the `.blend` that `retarget_mixamo_stand.py` writes. The tools' README names each
  script, the rifle layer, the `NGM_R_` clips and `SBOutfitProject`. The README and the page name the poses' folder
  that `fight/gunmode/overlay.lua` plays from (`Mods/NGM/Poses`) and the aim camera's modifier `mode.lua` adds
  (`BP_NGM_CamMod`). Gun mode's code, tests, tools and page hold no
  clock time of a play session unless it names its log (`UE4SS.log 2026-11-12 21:49`). They cite neither
  `NGM_FACTS.md` nor the rebuild's plan, which are not in this repository. The gun mode page names every table
  `fight/gunmode/data.lua` changes and the notice the parked key shows. It gives the grip's ease with the time
  constant `ik.lua` runs (`pin_blend`). While `mode.lua` ticks no HUD entry, neither
  the page nor `ammo.lua`'s header promises the `rounds | magazines` count. While it ticks one, the page says what the
  entry shows and names its icon (`Icon_Nikke_LostItem_AssaultRifle`, row `Nikke_AR`). The page, its docs index row and `coop gun`'s comment speak of no crouching.
  The page has no ", and" or ", but", no bold-label bullet and no
  "co-op session". `ammo.lua`'s header and `facts.lua`'s note on the retired F11 have no ", and" or ", but" either.
  The same holds for each run of comment lines in `input.lua`, `ik.lua`, `mode.lua`, `aimrot.lua`, `ui/dpad.lua`,
  `rifle.lua`, `ik_pin_test`, `input_memo_test`, `rifle_frame_test`, `morph_test` and `cost_test`. No sentence ends
  inside a parenthesis in those runs.
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
- `vehicles/bike/ride_test` covers `vehicles/bike/ride.lua` over a fake EVE and native part: the preload asked once and
  released at `bike=off`, the part made once (at the seat, hidden, its tick off) or found again after a reload, every
  mount refusal with its reason and nothing written, the mount's order and the dismount backward, the lean (the math
  library looked up once a ride), `bike_pose`'s two ways (on the rig way: the rig made in her body or the spare body,
  fields 8 and 9 written, a gone rig, an outfit change, a lost hook hooked again once and ending the ride the second
  time within 1 s, the rig released after Ctrl+R, the rig kept through photo mode, `pose_source`; on the hold way: the
  riding clip played again or ending the ride, read in the 250 ms pass only, as no frame reads the status), the 250 ms
  checks (EVE down read from the status line's `bike_life=` with no session, or from
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
- `vehicles/bike/rig_test` covers `vehicles/bike/rig.lua` with fake UE4SS objects: the follower rule (hung on her main
  mesh with no socket, no anim instance of its own and a mesh; the bike part left out by its address; address order),
  the rig made hidden, posing while hidden, its cloth off, snapped to her main mesh with the clip looped, a rig that
  cannot be made leaving no actor, the hook and the unhook (each part back once, a failing call counted while the
  others go on, nothing called once her EVE is gone, a part on a socket that the hook's cascade moved sent back),
  `hooked`, the sweep and the release after Ctrl+R (a root that is no `SkeletalMeshComponent` left alone);
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
- `cutmenus/mailbox_test` builds each `coop gift` notice through `tell` from a words table with a mark before and after
  every gift word and another mark around `friend`. It fails when a notice has text in front of or behind the word it
  was built from (an English literal, or English added to a word). With no name from the link, it checks that the
  notices for a gift got or kept carry the words' `friend`. It covers the loopback's own sentences and the reason of a
  stopped send in the log. It also
  stops a send with `coop off` before and after the remove: after it, the items wait in the gift file as a back entry
  that a new mailbox (the next game start) gives back, or the log says they could not be given back.
  `main/boot_test` checks that `cutmenus/wiring.lua` hands it `M.tell`;
- `online/partner/capture_test` also covers SBO's bike left out of the parts while EVE does not ride (`leave_out`, asked
  once a look): an outfit of 16 parts keeps them all; while she rides the bike is part 1 and the last follower goes;
  getting on or off starts a new generation; another component on the bike's mesh stays a part; her body on the bike's
  rig (`pose_source`, asked once a look): her main mesh, two followers and a ponytail with no leader give the table
  without the rig except part 0's `read` object, a new generation; on another mesh the rig's bone count, bone names
  and morph names; no table for a rig `pose_source` does not name or one without a mesh;
- the ghost bench (`coop bench`): `online/partner/bench_test` over fake ghosts and files covers the command's words
  (0 to 64 ghosts, the three tiers, `ring` 1 to 300 m, `nocloth`, `noshadow`, `add`; any other word refused with the
  usage), the refusal while her ghost is off, the ghosts on their ring with their tier's look on slots 101 on, their
  table from `coop-bench-table.txt` at the native part's count, their displays in `coop-bench.txt` with offset and
  stride, their paths in `coop-bench-ghosts.txt` as each is built, one log line a window with its text, `add` up to
  64, a second ring of the same size turned by half a step, a map change, `off`, a window left from an earlier run, a
  ghost that raises said once and the next Lua load's sweep. A lost `bench off` is written again at the next pass. A
  new Lua load writes it when it finds no bench file beside the out or table file, and writes nothing when none of
  them is there. Through `online/partner/wiring.lua` the bench ticks with the members' ghosts and
  `coop off` ends it. `online/partner/puppet_test` covers the tiers' looks: `look.lod` on every part (followers too),
  `look.shadow=false` on every part, `look.basesuit` (no mod-parts notice), `look.bare` leaving out a part with no
  fallback with its followers, `body()` nil before the first pose and once off. `online/partner/commands_test` covers
  `coop bench ghosts`, `off`, the status, two wrong words and the refusal without the native part;
- the ghost's drone, sounds and faces looks: `core/link_test` reads `drone`, `sounds` and `faces` (each on unless set;
  a bad value keeps it on with a line) and gives a file with 0.11's ghost comment the new comment once, with a line that
  names no setting. `coop-state.txt` gets `sounds=0` when the sounds look is off, nothing when it is on or not given.
  `main/settings_test` passes the sounds look to the state, `coop look`'s change at the next pass.
  `online/partner/commands_test` covers `coop look` for each of the six looks (the table the ghost holds changed, the
  ghost built again) and any other word refused with the usage, nothing changed; its help names the six.
  `ui/kit/model_test` puts the three rows after `effects` on the Ghost page; `ui/text_test` checks their labels in
  every language table;
- asset names: `core/link_test` reads a slot's `coop-names` file from an offset (whole lines only, false once the file
  is shorter, gone or has a new head line) and appends to its `coop-loaded` file (nil removes it).
  `online/partner/assets_test` loads what the slots name with one loader: one load each 0.25 s for every slot together,
  a path two slots name once, a slot's `loaded` line once all its paths are in, an object of the wrong class refused, a
  collected one loaded again with a new line (one whose address another sound took too, found by its full name), a
  failed load said once and not tried again, a mod's path only when both players have it (through the crash sentinel), a
  set-aside path never, a reset slot read again from 0 (one reset while unwatched too, by its head line), a kind the
  slot does not want never (until it is watched again with it), a path checked as each class a key names it as, an
  unwatched slot's file kept with no line appended twice once it is watched again, the loaded files removed by `off`. A
  collected object the check has not found yet is never asked its class when other lines are written.
  `online/partner/puppet_test` makes that loader once. It watches a ghost's slot once the ghost is built with sounds on
  (with the kinds its look wants), never with sounds and effects off. The slot is unwatched when the ghost goes;
- her drone: `core/link_test` reads `coop-drone.txt` (`drone()`: the address, nil for `none` or anything but 0x and
  hex digits). `online/partner/capture_test` adds the SBCharacter of class `CH_Drone_BP_C` at that address after her
  parts and the bike's, its main mesh a free part with a light line after its read line; hidden in game it goes with
  shown 0 under the same generation; another drone actor is a new generation; the look off, no address, an address no
  drone has or another class at it adds none; a drone that cannot be read is left out, said once; over the pose
  size its leader goes first. A drone mesh hung on no part hangs from the free part, placed relative to it.
  `online/partner/puppet_test` reads a free line strictly (none on a placed part, none missing on a free one) and draws
  the free part on part 0 with a box after the effect boxes on the display file's `free` line and a SpotLight on its
  `FX_Lens` socket (movable, no shadows, cone 40). At each pose it moves the part as its box says and shows it with
  its light at step x 4 while the box and the table say so, never in Doro mode. A Lua error there hides the drone on
  that ghost only. A part that turns free under one generation builds a new ghost. With the look off no free part,
  box or light is made, nor the parts that follow or hang on the free part;
- her face and shape keys: `online/partner/capture_test` names each part's morph targets on a morphs line after its
  names line (before its read line), a follower's with its morph_read line. It sends none over 256 on a part and
  none past 512 in a table, both named in the capture line. Over the pose size it drops the last part's morphs before
  any leader. Past the table's room it keeps the values and drops the morphs. Under one generation the morph lines
  stay as its first table had them. Faces off or on again is a new generation. `online/partner/puppet_test` writes a
  display morphs line per part drawn with morphs, after the drive lines, mapping her morphs by name (-1 for none),
  never for the cloth follower or a mesh past 256 morphs; with the look off none. Another morph count under one
  generation builds a new ghost;
- `core/link_test` also covers the status's `uidev=`, `me=`, `world=` and `story=` lines and the `owner=`, `room=`
  and `hall=` fields of a match lobby's `link=` line, each read as nil without it (`me=` also when the name is empty)
  and never from a player's name; the `shared_world`, `shared_story`, `daynight`, `pause_tab` and `hide_popups`
  settings (the `sky=` line kept out of the `link:` lines); `bike` and `bike_key` (an older
  file whose keys hold F3 gets no bike key); `bike_pose` (`rig` by default and in a new file after `bike=on`, `hold`
  taken in any case with no note, another word refused with its note and `rig` kept); `gun_mode` and `gun_key` (F4 by
  default, G refused, an older file whose keys hold F4 gets no gun key, a clash both ways) with gun mode's test lines,
  kept as written with no note; `fishing` (on by default, its template line after `scoreattack`); `photohunt` (on by
  default, its template line after `fishing`); `boss_finish` (first by default, right after `boss_hp_scale` in a new
  file, a bad value kept at first with a line); `spectate` (on by default, right after `revive`, a bad value kept at
  on with a line); the engine line logged again only when more than the items read's ask number changed (gun mode
  reads its rounds once a second); the mode lines (`mode_line()` a mode request, each member's
  line kept under its word with her SteamID apart from the chat and the other words, oldest first, 64 at most a word).
  It also reads the `dlcs=` line with the `dlc_missing=` and
  `dlc_extra=` lines after it, the `mycycle=` and `cycle=` lines (a value out of range dropped), the session list's
  `list=` line with its `session=` rows (a row only after a `list=` line, `-` read as none) and a joiner's `wait=`
  line, logged once a wait. It covers `who_can_join` (`public` by default, the older `code` and `private` read as
  `invitation`) and `friends_ask`, the `where` and `rules` requests
  asked only on a change and never with a word the native part refuses. The rules word is built from the settings and
  read back in that shape only. The parked bike's line goes to `coop-parked.txt`, the newest replacing one the native
  part has not taken. Each member's `bike_of=` line reads into `bikes()` by her SteamID and stays out of the log.
  `coop-state.txt` gets `collide=0` last when the state's collide is false, nothing when it is true or not given;
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
- the travel to the host, the return after death, camp rests and solo areas: `core/link_test` reads the `mate=` and
  `vit=` lines with 13 numbers (the zone type last; the 12 numbers of before read as no vitals), `Link.solo` (types 2
  to 6), `zone()` from the engine line's `zonetype=` and `area=` (type 0 and no area without that line), `spots()` from
  the `spot?=` and `spot=` lines (none once they are gone) and the `rest <zone> <SteamID>` lines of `coop-chat.txt`;
  `online/group/travel_test` the press on the host's map asking his spot (refused within 5 m or with his ghost
  hidden), his answers with their notices, the guards again at his answer, each member's spot answer (whole numbers,
  its reasons in order, a ground point older than 10 s read as air, a map change dropping it), the second hop 10 s
  after a camp travel to his map, `always` on his map, a solo area on either side refused, `go(id)` with its refusals
  and `coop travel spot`; `online/group/group_test` the return after death (the offer once per death, `back()` with
  the in-place respawn then the warp, `always` and its 5 s, the host's own death, the warp waiting while paused, no
  offer for each refusal, a solo area on our side or hers included), the solo notices for the others only, the
  revive, her down notice and the guest's cutscene pause leaving out a solo area on either side, then the camp rests
  sent and applied (one ResetZone call per zone each 30 s, SB's echo of our own call, the wait while busy, 60 s at
  most, the stop after 4 starts within 30 s of a call, each refusal with its log line); `online/partner/ghosts_test`
  each ghost knowing from her zone type whether the member in its slot is in a solo area;
  `online/partner/puppet_test` her ghost hidden in a solo area with one line a stay, back at the next stamp;
  `main/boot_test` her zone type reaching the ghost, a rest line reaching the group module once, `coop travel spot`
  and the return's press; `fight/enemies/wiring_notices_test` the same place and same spawns notices silent with
  `shared_world=on`, where the group module's rested notice says it;
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
  bike's key and Reset all keys, the Spectate row (on by default, in effect at once) and the Boss finisher row
  (First press by default, or The host only). The bike's riding pose row comes after the bike's key (`rig` by
  default, `rig` read for any word but `hold`). The Options paragraph names it after the bike's key and before gun
  mode's key; `main/menu_test` the Boss finisher row in the scrolled Options view;
- `online/group/travel_test` covers the host's row in the session list: the rules word at each change, the map and
  nearest camp at once on each map and once a minute at most, from the follow's spawn point read (read again a minute
  later when it found no camp), nothing in a load, as a guest or in a match lobby. A refusal is logged once. For the
  bike's paid fetch, `camp_near` finds an activated Xion camp whose spawn point stands within 10 m on Xion's map,
  walking the spawn points once a map;
- `online/group/group_test` covers a Lua reload while the revive hides the death screen: `coop-death-screen.txt`
  written at the hide with the visibility from before (Visible in the test) and the screen's address; the new load's
  first tick looking the screen up once and taking it over while it has that address and reads Hidden, at each of two
  reloads; the screen shown again as it was at the next death, with no session and at `coop off`, the file removed
  then. A file whose screen no longer reads Hidden is removed and the screen left as it is. A file whose address is not
  SB's death screen's is removed and the widget that reads Hidden left as it is, with no session too. No file, or a
  file without both numbers, means no lookup. A file that cannot be written gives one log line;
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
  status; `pvp_spike=off` ending an earlier load's PvP test at a reload). For phase 3 it covers `boss_finish=host`
  as `finish-host` right after the bosses percent, the `spectate` ask (at load only where the `engine=` line's word
  disagrees with the setting, none for `faulted`, cancelled by `coop spectate on` or `off`; the Options row's ask at
  once), `coop spectate` with its words (test on a co-op save only) and spectate's tick in fight's 250 ms work, after
  `coop off` too;
- `fight/enemies/wiring_notices_test` covers the same place and same spawns notices in both languages, the finisher's
  notice (once a winner, never for ours) and the QTE notices at each change of `qte=`;
- `fight/enemies/spectate_test` covers `fight/enemies/spectate.lua` over fakes of the link, the controller,
  `core/actors.lua` and `core/unreal.lua`: an earlier Lua load's camera swept, one camera made and the view taken once
  from our pawn only, a theater's camera kept on both edges, the camera's place each frame (400 cm from her feet, 160
  cm up, aimed 130 cm above them, its direction kept), one respawn per reason with the revival once 2 s later while
  the life did not move, the 2 s stopped while the line reads `fight=waiting`, each refused respawn with its log
  line, the view back at `spec=0`, the native fault's fallback, the camera over our EVE with no ghost anchor, the
  switch among the members alive on our map, the watching notice once and `coop spectate test`'s probe and line;
- `online/session/wiring_dlc_test` covers the DLC notice: once a session when the two lists of installed DLCs differ, in
  the menu's language with its English beside. The same DLCs, or no list yet, give none;
- `online/session/wiring_cycle_test` covers the New Game+ notice: the guest compares with the host, the host with each
  member; one notice a member while the values differ, one more on a change, in the menu's language with its English
  beside. The same values, ours not read yet, a match lobby or the SBO lobby give none;
- `story/quests/wiring_test` covers `coop quests` with the `shared_quests` and `quest_deny` settings and the shared
  quests' notices;
- `main/gun_test` covers gun mode's wiring through `main.lua` with a fake `fight/gunmode/mode.lua`: the mod folder
  it reads its `gun_` lines from, the rounds' store (none without the native part), its start, the words and the
  notice it gets, the new-controller hook, no unknown-setting line for its `gun_` lines, the restore at the first
  tick, `coop off`'s stop, the restore alone after a Lua reload with `coop off` still on;
- `main/bike_test` covers the bike's wiring (`vehicles/bike/wiring.lua`) through `main.lua` with a fake
  `vehicles/bike/ride.lua`: the load line, what the ride gets (its asks, `coop-bike.txt`, the driving, the settings,
  SBO's busy reasons with coop fly, gun mode's rifle and our open screens), `coop bike` and its words, F3 and the pad's
  D-pad Right hold with a refusal on screen, the hold ignored with its reason logged at the title, with one of our
  screens open or with the game paused, the restore, the frame and the 250 ms pass with an end said on screen, the
  Options rows, `coop off`; `riding()` as `coop emote`, the race, the hall seats, `coop fly on` and `coop glide on` read
  it; the ride's `idle_part` as the capture's `leave_out` and its `pose_source` as the capture's; what the parked bike
  gets (the menu's words, a notice, SB's text by table path, the travel worlds, its record through the link's files,
  `coop-bike-stand.txt`, its bike line through `link.bike`, the paid fetch with `coop gift`'s FName and pause rules, the
  follow's `camp_near`); the other players' parked bikes built, restored at the first tick, run after the ride's pass
  and cleared at `coop off`;
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
  first live pass, a streaming level whose read raises, one kept from the world entry that is no longer valid (never
  read, logged once); the Terrace hall left alone; with the keep, no star material
  loaded at dusk until it is in; a dome actor that comes back at the freed address of the old one, whose star layer
  went with the old actor, gets it looked for and made again;
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
  session. The state's `collide` follows the same rule (`collide=0` stops the enemy contact);
- `main/pass_test` covers the module exports that `main/pass.lua` and `main/frame.lua` call under `guarded()`. With
  `fight_asks` raising, the 250 ms pass still says the link's notices, starts the ghost, writes the state and runs the
  kit's slow pass, the focus watchdog and the menu's slow pass. The error is logged once under `fight`. Then
  `quests_asks`, `world_asks`, `scenes_asks`, `puppet.active`, `ghost_start`, `race.armed` (in the pass and in the
  frame), `sbo.active` (before and after `coop off`), `group.photo`, `group.cut`, `booth.near`, `hud.marking`,
  `photo_pause` and `puppet.rebuild` each raise in two runs of their loop: no error leaves the loop and one line is
  logged under the module's name;
- `main/boot_test` checks that the usage line names `coop guide`, `coop teamshop` and `coop spectate`, which
  `docs/usage.md` lists as player commands;
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
  game reads. For spectate it covers the pad's left and right that nothing else took switching the member watched
  (the co-op menu open takes them first), the Left and Right arrows the same way (never A, Q or D, nothing while it
  does not watch) and the camera's frame call right after the ghost's place;
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
  `coop-settings.txt`, Select on Challenge cycling the pick over what the room offers), the Doro race's rows (its
  match round's pick in the view while `race_match=on`, none with it off, Select on Track cycling the host's track over
  what the room offers while score attack's pick stays), the countdown feed, the start line (a score attack or Doro
  race round's start logs its mode; its end line opens B again, once), the focus watchdog and the `hud hide` requests
  (`off` at the first pass after a load, then `on` and `off` once each as the screens open and close, and one that
  cannot be written logged once and asked again; `main/fixture.lua` keeps them apart from the other requests); last, the
  arrival's hold: after a lobby warp, ClientRestart's hook puts SB's black up at the next pass (`LoadingScreenFadeAuto`
  with a 10 s lifetime, 0.5 s fades and tag 5) and veils the kit; `hud hide on` is asked under it from the arrival on,
  passes before the lift; the menu camera takes the view while B waits, and once nothing is missing `loading lift` is
  asked, the veil goes and B opens in that pass with SB's HUD still hidden; a Lua load under an earlier load's hold asks
  `loading lift` once, at its first pass in the lobby world and not before, and none when that pass also puts up its own black (one fade); without the hook, one log line;
- `online/modes/scoreattack/model_test` covers score attack's round without the game: the challenges planted rooms
  offer, the host's pick and its Random draw, the score texts and their refusals, a run's result, the host's checks
  against honest and inflated runs, the ranking with shared places, then the host's wait over a fake clock (ready,
  done, refusals, leavers, a late ready, the deadline, the rank text and the match's end).
  `online/modes/scoreattack/round_test` covers the round on a fake link and clock: the host's draw, go, checks, rank
  and match end, a guest's go read before its start line, her rank and a void, who may send which line, the pace of
  the now lines, a round that ends early, one replaced by the next, one found playing at a Lua reload, a room that
  offers nothing, a player who leaves, the pick and its cycle. `online/modes/scoreattack/game_test` covers each
  sit-out reason with its log line and notice key (SB's own chair seating EVE among them), a hall seat left first,
  the run at the spot facing the ring centre on the round's seed, the now lines while its waves play only and the
  done line of each outcome.
  `online/modes/scoreattack/run_test`, `challenges_test` and `waves_test` hold their Night Operation originals' cases
  for the copies, with what the copy changes: each start refusal with no spawn, a whole Target Practice run from a
  lobby spot, `best_match_targets` kept in `coop-records.txt` beside the solo bests, every abort and, after a death,
  the in-place respawn (its checks, its 10 s, its result line, the death screen hidden and shown again).
  `online/modes/scoreattack/board_test` covers the card, the in-round board and the result panel on a fake kit, their
  words in the game's language, the notices with the kit off and the HUD's STOP line. `main/scoreattack_test` covers
  the pass line and the `coop off` stop through `main.lua`, then the wiring on a fake run, SB's chair sit-out with
  its notice included;
- `online/modes/race/match/model_test` covers Doro races in matches without the game: the dr texts both ways with their
  refusals and sizes, who may send which text, the track coming whole from its lines, the tracks planted rooms offer
  (Xion's training room with its 30 m fence, a hall, a track in Xion's streets left out), the pick and the Random draw,
  the split floors, the host's checks against honest and forged splits and ends, its wait over a fake clock (leavers,
  refusals, late readies, both deadlines, the rank text and the match's end), the ranking with shared places, our race
  from the start line to the results, the best times in `coop-records.txt` and `coop-tracks.txt`; each official track
  file parses, names its room's map and fits its fence. `online/modes/race/match/round_test` covers the round on a fake
  link and clock: the host's draw, its track lines one a pass, its checks, rank and match end, a guest's track read
  before its start line, its rank and a void, a track that does not come whole, who may send which line, a round that
  ends early, one replaced by the next, one found playing at a Lua reload, a room that offers nothing, a player who
  leaves, the pick and its cycle. `online/modes/race/match/game_test` covers each sit-out with its log line and notice
  key, a hall seat left first, the ghosts by SteamID, ready after our race started, our splits and end to the round,
  the records written only for a better finish and the round's end before and after its ranking.
  `online/modes/race/ui/hud_test` covers the race's HUD: the live place among up to 8 racers, the results' note and
  rows (a session's two, a match's own row before the ranking, then the ranking with names cut, `Not ranked.` and
  `New personal best.`) and the 8 result rows on a fake kit. `online/modes/race/run_test` adds the match role: the
  teleport onto the slot at the start and back at GO past 3 m with the runner starting from the slot, a racer that
  SB's chair seats at GO out of her slot sitting out with the seat notice and a DNF quit instead, every round
  player's ghost as a Doro, `coop race start` refused in a match lobby, the round ticked from the 250 ms pass, the
  place notices with the kit off. `online/modes/race/drive_test` and `doro_test` cover the asks to the native part
  (`race hold`, `race tick`), the impulses only while the status says the hold is applied, a hold still applied with
  no drive asked off again, nothing written to the four values or the tick option from Lua. They also cover an
  older `coop-look.txt` with a number in its tick field that writes nothing. `main/race_match_test` runs a round through
  `main.lua` and the wiring: the official track read from the Scripts folder, the host's lines one a pass, a hall's
  own tracks from `coop-tracks.txt`, `coop race save` and a pick by name adding to it, the sit-out notices, the host
  gone, the records file, `coop off`, the wiring's adapters (SB's chair read by the race too). `main/isolation.lua`
  checks with the race module off that the lobby menu holds no race and refuses Select on Track;
- `online/modes/fishing/model_test` covers the fishing tournament without the game: the start's length (10 minutes by
  default, 1 to 60), the clock, each fish text's round trip and every malformed one refused whole, who a game takes
  each text from, the host's checks of each catch (sender, seed, fish, points, time and the rate bound, both from 1 s
  before the host's GO, an honest guest whose GO comes 1 s before the host's to 3 s after it never refused, a flood
  cut at the bound), the standings with shared places, a leaver and a link that comes back, the board at most once a
  second and the rank text with its minutes for 2, 4 and 8 players. It covers the catches from book reads too (the
  baseline, a rise, a fall, a fish gone, two catches in one read, a jump of 3). It also checks the 40 row names of
  `rows.lua`. `online/modes/fishing/round_test` covers the tournament
  on a fake link and clock: `coop fish start` and its refusals, the host's go, board, each refusal with one log line a
  sender and reason, the rank and its record, a guest's go, ready, catch, board, rank and record, her sit-out and the
  lines she drops, a guest who is lost and comes back, the host leaving, another host's session, `coop fish stop`, a
  guest's Lua reload (her notice at the first board that names her, her record from the rank's minutes), the host's
  (a void at the first catch of the old seed, `No ranking came from the host.` 30 s after the end), a pass whose status
  was not read and 2, 4 and 8 players. `online/modes/fishing/game_test` covers the fish table read from SB's two
  tables by row name (a missing row, a bad value, a shared ID), each sit-out, the engine line's book answers, the asks
  once a second from GO with a number the engine line never shows, a lost answer asked again after 3 s, the last ask at
  the end, each event that takes the baseline again (a map change, a loading screen of several passes, a slot change,
  each `none` but `unread`) with the answer of an earlier ask dropped, a fall, a jump and a fish not in the table.
  `online/modes/fishing/board_test` covers the corner board and the result panel on a fake kit (their places, the
  countdown, ours in teal, a pause, the title screen, the ranking, the panel closed 20 s after it), their words in the
  game's language, each notice with the kit up and with the kit off and the HUD's STOP line.
  `online/modes/fishing/records_test` holds the cases of score attack's records for the copy under `best_fish_`.
  `online/modes/fishing/fishing_test` covers `coop fish`. `main/fishing_test` covers `coop-records.txt` through
  `main.lua` (no file, a write that fails, a refused rename, a file that cannot be opened), the pass line with the book
  asked once a second from GO, the corner board built on the kit's hud step, the `coop off` stop with no line and no ask
  after it and the guard on the pass line;
- `online/modes/photohunt/model_test` covers the photo hunt without the game: the start's length (15 minutes by
  default, 1 to 60), the clock, the host's draw of three distinct targets, each photohunt text's round trip and every
  malformed one refused whole, who a game takes each text from, the host's checks of each claim (sender, seed, row,
  taken, again, time), the first claim winning, the board, the ranking with shared places (0 points sharing the last
  place), leavers and a link that comes back, the end at the third point and at the time for 2, 4 and 8 players, the
  native part's answer, what a new answer brings (valid photos, the last shot's answers) and the words of a shot.
  `online/modes/photohunt/round_test` covers the round on a fake link and clock: `coop photohunt start` and its
  refusals, the host's go, board, each refusal of a claim with one log line a sender and reason, two claims of one
  target in one pass, the rank at the third point or at the time and its record, a guest's go, ready, claim, board,
  rank and record, her sit-out, her end at a full board and the lines she drops, a guest who is lost and comes back, a
  guest lost at the rank, the host leaving, a guest who leaves or whose rejoin gives up then comes back,
  `coop photohunt stop`, a guest's and the host's Lua reload, a pass whose status was not read and 2, 4, 8 and 9
  members. `online/modes/photohunt/game_test` covers the targets walk on fake tables (a row of the map, of another
  map, with no ZoneEnvSpawnTable row, with two zones, fewer than three rows, a read error, no world loaded), each
  sit-out, the ask at GO only with a number the engine line never shows, a lost answer asked again after 3 s,
  `M.fname` nil for one row and for all, the answer's valid photo rising (a claim) or jumping by 2, the shot's words
  given before the host's own claim, each `none` answer, a map change with the ask kept armed and no target read
  again, the end at the time, at a full board and at a ranked round, `coop off` and `coop photohunt try`.
  `online/modes/photohunt/targets_test` covers which rows of a fake walk lead to a map and a row's name on screen.
  `online/modes/photohunt/board_test` covers the card and the result panel on a fake kit (their places, the countdown,
  ours in teal, a pause, the title screen, the ranking, the panel closed 20 s after it), their words in the game's
  language, each target taken said once, the photo words queued until the selfie mode closes, each notice with the kit
  up and with the kit off and the HUD's STOP line. `online/modes/photohunt/records_test` holds the cases of score
  attack's records for the copy under `best_photohunt_`. `online/modes/photohunt/photohunt_test` covers
  `coop photohunt` with each refusal and `try`. `main/photohunt_test` covers `coop-records.txt` through `main.lua` (no
  file, a write that fails, a refused rename, a file that cannot be opened), then a host's round over a fake clock: the
  ask at GO with the targets' FNames, the screens built on the kit's hud step (the start and Camera notices, the card
  each pass, hidden on the title screen), a valid photo in the engine line making the host's claim and board, the photo
  words after the selfie mode, a fault answer's notice, the `coop off` stop with no line and the ask taken back, the
  guard on the pass line, `photohunt=off` and a save that is not a co-op one refusing the start;
- `online/modes/nightop/recruiter_test` also covers the auto spawn at each Xion load (waits while the spawn point is not
  loaded or EVE is too far, one spawn a load, a guard kept after a Lua reload, none after `coop recruiter off`). It
  checks the arm call right after the spawn and at a guard already there, before any check. It runs the looks every 3 s
  until +30 s with a guard who comes at +9 s, one who never comes and one 4 m off the point;
- `ui/kit/wheel_test` covers the wheel (`ui/kit/wheel.lua`) on a fake kit: the slot under a direction for 3 to 6
  slots, the stick's sectors, the pages split (11 emotes as 6 and 5), the game's piece sizes and pivots at 80 %, the
  open (the input taken with no cursor, the mouse centred), pointing with the stick and the mouse (past 60 units, once
  moved), the highlight that stays, the release that plays once or nothing, the input back 150 ms later, a click, A,
  Esc, B, the pages, a guard, the window lost, the HUD hidden, the refusals and `coop off`;
- `eve/ui/wheel_test` covers the emote wheel's pages (5, 5, 4, 5, 6, 5, 3 and 6 slots, each of the 39 emotes once),
  the game's words first and only for keys `StringTable_UI` holds, the waves' sides, SBO's words with
  `ui_language=english`, the refusals in the player's words with English for the line above EVE, a pick through
  `coop emote`, its refusal on screen and the page used last; `main/input_test` the keys and the pad on the fixture
  (F2, Q, A, E, Esc, the mouse buttons, the other keys dropped, D-pad Left's event, LB, RB, A, B, `emote_key=none`,
  `emote_pad=off`, an older DLL, a wheel that does not build, `coop off`); `eve/emote_test` EVE's busy reasons;
- `eve/ui/tools_test`, `cutmenus/ui/devmenu_test` and `fight/bosses/ui/viewer_test` cover the three TEST TOOLS pages:
  their rows, the commands each row runs, the values after accepted and refused commands (a devmenu switch's Off
  running `clear` and every lasting switch then Off, the lock-on's `lockswitch`), the viewer's parts and skins per
  model and every shown value within the menu's value column; `ui/kit/model_test` the pages' rows on the main page and
  in their own page; `main/menu_test` the three pages drawn and run on the fixture;
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
  four idle mode rows with the picked mode marked, the score attack's Challenge row and the Doro race's Track row (the
  pick beside it, a track's name cut at 18 columns and kept whole at 18, a guest's locked and reading the host's pick,
  in tab MATCH too), every row slot synced when the mode rows go from four to three, the cursor kept on its action row,
  and that
  no part is ever focused, clicked through or sent a call outside the allowed list;
- `online/lobby/ui/lobby_model_test` covers the lobby menu's rows, actions, status and members by state, the settings
  rows (the Map row only with no lobby open and the hall lobbies in use) and the countdown's resync. It also covers the
  mode rows: score attack picked first while it can play, a mode row picking the mode that Search and Private match
  ask for, the Challenge row of a score attack match lobby and the Track row of a Doro race match lobby (the host's
  pick, locked for a guest, locked while the mode cannot play) and tab MATCH's rules of each mode;
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
  name. So do `coop gift`'s notices with a 32-byte name and alias, and the guest's Night Operation start notice with
  each level's word. Her card's title with each level's word stays within the card's 43 columns. Score attack's notices stay within 200 bytes too (each sit-out, a round without a ranking, the end and the
  place with the UI off). Its screens' words stay within their columns: a board row's name and its score with the wave
  or end word, the result panel's heading, its line with the longest end word, its notes and the difficulty words.
  The fishing tournament's notices stay within 200 bytes with 32-byte names (the start of 60 minutes, each sit-out,
  an end with no ranking, a reloaded game; with the UI off GO, the place, the end, the first three with 6-digit points
  and a new best). Its corner board's title line, the result panel's heading, its line, its notes and a ranking row's
  fish stay within their columns. The photo hunt's notices stay within 200 bytes with 32-byte names (the start with
  the longest place and target names for 60 minutes, a target taken, each sit-out and each stop of the photo checks, a
  photo's words with the longest target; with the UI off GO, the end, the first three, the place and a new best). Its
  card's title line and target rows (the longest target name with two-digit numbers, a taker's name cut to 19
  columns), its last line and the result panel's heading, line and notes stay within their columns;
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
- `world/maps/sboxion/rows_test` checks SBO Xion's two rows in `world/maps/sboxion/data.lua` against
  `world/maps/sboxion/sboxion_rows.h`: names, templates, each patched field, the IDs 7131 and 1000131 outside the
  hall lobbies' blocks, no name ending in `_<digits>` and the 41 names of the day table, none twice;
- `world/maps/sboxion/title_test` covers the pak gate and the title's ask over fake files, tables and a status text:
  no pak or a container without `Xion_P.umap`, nothing asked or logged; with the pak, nothing on your own saves, one
  ask on the co-op save files with the two tables, read back; a taken ID or rows that read back wrong refuse with
  one log line; a shut gate's refusal is asked again 10 s later; `coop off` ends the wait;
- `world/maps/sboxion/world_test` runs `world/maps/sboxion/sboxion.lua` on a fake world of 72 env volumes and 95
  streaming levels. `coop xion` refuses on your own save, in a session, without the pak, after refused rows, after a
  fault and inside SBO Xion, each with nothing asked. Its request holds the zone's FName index, the point in whole
  centimetres and the yaw, for each of the two points. `coop xion leave` asks from any map. The native answer is
  logged once. No answer in 10 s is logged once. At an arrival the 41 volumes of `E04_ENV_VOL` are set (21 writes), a
  volume of the same name in another level is left alone, the log reads 72, 65 and 41. The read-back comes 2 s and
  10 s later. A write that does not hold shows in the read-back. A level not loaded is named. In another map nothing
  is read. A second arrival writes again. A change of a probe level is logged once. A waypoint is logged after 5 s
  within 3 m, once a visit. A map change, a loading screen and `coop off` end the watch. The recovery is ticked only
  in SBO Xion. Each arrival starts it again with the arrival point `coop xion` asked. Its ground point and its fall
  line hold the engine's read of EVE when `me()` names another place. At that fall SB's black is asked once through
  the module's own wiring, nothing moves in that pass and the move comes two passes later. A `life=3` word gets the
  respawn asked with the GUID of the `engine=` line. A death screen it hid is shown again at a map change and at
  `coop off`. `coop xion recover` is refused outside SBO Xion, sets each of its three modes inside and prints the
  state alone. A stay left in the mode `death` is followed by an arrival in the mode `on`. `coop xion status` ends
  with the recovery's part and the rooms' part inside SBO Xion only. No wall call and no walls part are left. With
  the pak of 23 November an arrival logs one rooms line and asks no piece. With the five room levels in the pak one
  line says the pak holds 5 of the 10 rooms. The arrival's pass opens those five, their hidden rows go to the store
  the wiring hands over, `coop xion rooms` is refused outside SBO Xion and prints, closes and opens them inside. A
  map change that took the world calls no row. `coop off` puts every row back. At a map change and at `coop off` the
  recovery ends before the rooms close. With two room levels in the pak those two open, the pak asked once a room a
  Lua load. With the full test pak's 161 levels the 34 volume-streamed ones are counted apart and never named as
  missing, 155 characters beside EVE are counted by class with only the five nearest named (class and distance) and
  the ten rooms of the third build's pak open. The zone and area of the `engine=` line and EVE's life state are
  logged at the arrival and once at each change, within a second. The levels line and the characters line come
  again 10 s later. A look 10 s after that
  reads once and says nothing. The next look says the two levels that changed and the characters line with the two
  that spawned, once. `coop xion status` ends with the last look;
- `world/maps/sboxion/tetrapod_test` runs `world/maps/sboxion/tetrapod.lua` over a fake world. SB's point inside
  the Tetrapod reads (81, 624, 332) in the ship frame. One pass in the doorway of the hangar moves nothing. The
  second asks SB's black. Two passes later EVE goes to the point inside plus 10 cm. Nothing is looked at for the next
  8 passes. Two passes in front of the ship's right door bring her to SB's point in front of the Tetrapod. A pass
  outside the box starts the count again. A busy recovery counts nothing. A refused teleport and a black that raises
  change one log line. An error in a pass turns the door off until the next arrival. `coop xion tetrapod in` and
  `out` ask the move at once. The way in asks the engine to make the ship's parts solid before the move. The way out
  and `coop off` put them back. While EVE reads 60 cm under the point she is put on it again and the ship is asked
  again if it was not found, with a black every 6 passes. After 32 passes with no floor she is put back outside;
- `world/maps/sboxion/recover_test` runs `world/maps/sboxion/recover.lua` over a fake world and a fake status text.
  The ground point: three walking passes give none, four give the first of the four, a falling pass keeps it, a step
  of 2000 cm starts the streak again, walking under the floor and passes on one world time add nothing. The fall:
  with EVE under Z -3275 SB's black is asked (0.3 s in, 1 s black, 0.5 s out) and nothing moves in that pass. Two
  passes later she goes to the ground point plus 10 cm with its yaw, or to the arrival point with no ground point.
  A black that raises, that SB did not make or whose handle did not read changes one log line and not the move. The
  move is held back like a check while a guard waits or the world's time stands still. The mode `off`, an arrival, a
  stop, a death that starts and an error in a pass drop it. After a failure the move is made at once, then a black
  that is up at once, none after a refused teleport. One black is asked a put-back, the one after a respawn
  included. Nothing moves and no black is asked while a guard waits (no EVE, photo mode, a cutscene, a warp, another
  zone or zone type), while her life reads 3 to 5 or in the modes `death` and `off`. Without a `warp=` word the fall
  is still caught. It is caught too with `theater=fault` and with `zonetype=0` beside SBO Xion's area. The check: a
  walking read within 3 s of world
  time is the success, 6 s of passes on one world time run nothing out, 24 passes in 0.75 s of world time are no
  failure, three passes of 1 s each are one, a refused teleport sends the next try to the arrival point, the second
  failure stops the recovery with no third call, the mode word starts it again, an error in a pass counts as a
  failure. An arrival sets the modes `death` and `off` back to `on`. An arrival, a stop, an error in a pass and the
  mode `off` each drop a put-back being checked. A put-back that leaves her under the floor is not made again while
  it is checked: the check fails after 3 s and the next try goes to the arrival point. The death, with the respawn
  cases of `online/modes/scoreattack/run_test` for the module's copy: each reason the respawn waits for is logged
  once, one call with her GUID, the result line 2 s later, the death screen hidden over a living EVE and shown again
  at a new death (in the modes `off` and `death` too), at a stop and when two failures stop the recovery, no call in
  10 s given up. The death screen is told once that its revival ended when she lives and never while she is dead. No
  widget and a call that raises each change one log line and not the result. A hide of the death screen that raises
  is one log line. The result line still comes with the screen `up` and counts no failure. The module's own cases:
  the call after
  5 s with no death screen, the put-back when the respawn leaves her off the ground (in the mode `death` too, never while a guard waits), life still 3 after the call as a failure
  that starts the death again, a death left from the mode `off`, one read during a wait and one on a world time that
  stands still, a life back at 1 before the call (one line, then the next fall is caught), no call without a `warp=`
  word, the `life=` word read on the refused and fault forms, a death dropped by an arrival,
  by a stop and by the mode `off`, the failures at 0 after a respawn that leaves her walking, a put-back's check
  dropped by a death that starts during it;
- `world/maps/sboxion/engine_test` covers `world/maps/sboxion/engine.lua` over fake UE4SS objects. The parts of SB's
  Tetrapod interior get SB's collision profile `BlockAll` by a name the game has made, then `NoCollision`, the
  profile SB ships them with. With no actor in memory nothing is written. The rest: the zone's FName index only for
  a name the game has made, each env volume's `bActiveVolume` read and written on its own actor, a
  dead actor never written, the streaming levels by their package's last part, the probes read again on the kept
  objects, the characters' names, classes and places with EVE told apart by her address (one that does not read
  given as `unread`), every world read raising with no EVE. For the recovery: `move` gives EVE's place,
  yaw, movement mode, world time and address from one EVE with each read made once; `put` teleports then stops her
  movement, with no stop call after a refusal; the respawn's controller, standalone test and request with the GUID
  and `false`; the death screen looked for only on request, read playing or not, hidden and shown again as it was
  (visibility 4, not 0), a dead widget left as it is; the widget told once that its revival ended, by the event name
  SB's dead HUD compares, a dead widget looked for again and not told. For SB's black, the module's copy of the
  lobby's call: one `LoadingScreenFadeAuto` call with the time the black stands, a fade-in from 0 to 1, a fade-out from 1 to 0 and
  tag 0; a fade-in of 0 s goes from 1 to 1; `true` for a GUID that is not zero, `false` for a zero GUID, `nil` for
  one that does not read; a raise of the call reaches the caller. No wall call is left. For a piece of a room's
  doorway: found by its names and refused for another class, mesh, place or instance count, a whole component hidden
  with its two values read first, an instance scaled to nothing where it stands, a piece that reads hidden already
  refused, the put-back and no call on an object that is gone;
- `world/maps/sboxion/rooms/list_test` checks `world/maps/sboxion/rooms/list.lua`: the ten rooms with their levels,
  the 41 rows as the level dumps of build 26123051 gave them, 18 whole components and 23 instances of 18 instanced
  components in 10 sublevels, no piece twice, the instance count of each instanced component (the same in the two
  rooms that share one), each room starting with its door piece, `D039` left out, each door a waypoint of
  `data.lua`;
- `world/maps/sboxion/rooms/rooms_test` runs `world/maps/sboxion/rooms/rooms.lua` over a fake world, a fake pak gate
  and a fake store. The gate is asked for each room on its own. With a pak that holds no room it logs one line with
  the first reason and reads no level. With a pak of the second build one line names the five rooms it holds of the
  ten. They open in one look once their levels read loaded and visible. The other five are never looked at. A pak
  with two rooms opens those two. A room whose ask raises is left out. With all ten the ten open, `D036` and `D158`
  each hiding their own instances of one component. A room waits for a missing level and closes
  after 30 looks. A row that is not found closes its room with nothing hidden. A row that cannot be hidden closes
  its room with the rows before it put back, while the other rooms open. The put-back asks each hidden row once,
  with a world that still stands and with one that is gone. `coop xion rooms off` puts the rows back and `on` opens
  the rooms again. The store keeps one line of the values read before each hide, the next Lua load's sweep puts
  those rows back, a store that raises stops nothing and a level read that raises is logged once;
- `world/maps/sboxion/sboxion_test` covers the words of `coop xion`: alone and `city`, `gate`, `leave`, `status`,
  `recover` alone and with `on`, `death` or `off`, `rooms` alone and with `on` or `off`, the use line for `walls`,
  any other word or one too many and the answer without the Steam link. Then `world/maps/sboxion/wiring.lua`: SBO
  Xion is built with the Steam link's store `coop-xion-rooms.txt` alone and no store is asked without the link;
- `world/maps/sboxion/off_test` runs `main/isolation.lua` with `world.maps.sboxion` (see the module tests above);
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
  `aggro-host`, `bosses <boss %>`, `finish-host` (only right after the bosses percent), `reactions`, `resist`,
  `spawns`, `extra <n>` and `filter` words,
  `fight stagger <0|1> <0|1>` and its `pilot` requests, `test target` and the boss tests included; `coop fight pvp` and
  `pvp off`; `lion rows`, `gardener rows`, `tendril rows`, `bolt rows`,
  `mxiii rows`, `shop rows` and `signal rows` with their 25 table words and bad addresses, the longest of them 813
  bytes; `fly` and `slowmo` on or off; `anim play` with its id, path and `once`, `loop` or `ride`, and `anim stop`;
  `bike load <clip>`, `bike free`, `bike gate on` and `bike gate off`, a mesh, a package path or a mod's clip refused;
  `shortcut list` and `shortcut load <map> <1-4>`; `hud hide on` and `hud hide off`; `pausetab on` and `pausetab off`;
  `popups on` and `popups off`; `loading lift`; `sky off`, `sky hold`, `sky cycle <hz> <H>` and `sky hour <minute> <hz>
  <H>` with their ranges; `world` and `scenes` with `on`, `off` or `status`; `nightshop`, `roxanne`, `lily`, `guardtext`
  and the 8 `signal` words, in `story/quests/own.h`'s order; the `sbo` requests (`on`, `arm`, `enter`, `warp`, `abort`,
  `leave`, `seq`) and their refusals, the score request, the mode request (`mode <word> <text>`), `fishbook <ask>` (1
  to 65535, 0 and 65536 refused), `photohunt <ask> <index> <number> ...` with 1 to 3 rows or `photohunt off` (an
  ask of 0 or 65536, an index of 0, a value over 32 bits, 0 or 4 rows and a doubled space refused), SBO Xion's
  `sboxion enter <index> <x> <y> <z> <yaw>` and `sboxion leave <index>` (an index of 0 or over 32 bits, a place or a
  yaw out of range, a missing or extra word refused; `sboxion rows` stays the rows request of batch 18), the dr request,
  `race hold` and `race tick` with `on` or `off` and nothing else), Night Operation's night line (its round trip,
  its refusals and a fuzz seed), the score line (Lua's text after `score`, printable ASCII up to the 512-byte message, never read as
  a race line, another protocol's refused, a fuzz seed), the mode line (its word of 1 to 16 lowercase letters, then
  Lua's text as it went, never read as a score or race line), the dr line (the same way as the score line, never read
  as a race or score line), and
  the join codes (both real lobby ids, loose typing, malformed codes, and the share of one-character typos the check
  turns away), the masking of SteamIDs, lobby ids and join codes in the logs and the report (`masked`, with the numbers
  and words of the same shape it leaves whole), the match modes (`find_mode`: `ffa`, `scoreattack`
  and `race`, nothing else), `match search` and `match create` with
  their room and hall words (each refused when missing, extra, too long or not an alias word), `match cancel` and `match
  end`, `mute` and `unmute`, `block`, `unblock` and `unblock all`, the `host` words (`public`, `friends`, `invitation`
  with the older `code` and `private`, `closed`, then `ask`, then `max_players` from 2 to 4), `list
  public|friends|stop`, `where`, `rules` and the row cleaner, the match lines (start, count, end) with their bounds, the
  host's let and wait lines with theirs, the dlc and dlcs lines with their bounds, the DLC comparison by app id, the
  cycle line with its bounds (count 0 to 99, difficulty 0 to 2) and a fuzz seed, the bike line (`none`, or `park` with
  the map rule, three places within 10,000,000 and three angles within 36,000 as signed whole numbers), the
  `coop-state.txt` line with `cut=`, `names=`, `sounds=0` and `collide=0` in that order only (the longest 82 bytes),
  the vit line's 13 numbers (the zone type last, 0 to 6; the 12-number line of before refused), the `spot?` and `spot`
  lines (places within 10,000,000 cm, a yaw within 360, the six reasons) and the `rest` line (a zone alias, a SteamID
  other than 0) with a fuzz seed each, Lua's `spot?`, `spot`, `rest` and `travel spot` requests,
  `spectate on|off|status|test` and nothing else, a player's life from her vitals (life state 2 read as Coma before
  the 0 HP rule), then protocol 29 refusing a protocol-28 lobby and line;
- `link_core_test`: the link against the shared fake Steam, and two links through it with the handshake both ways,
  channel 1 and channel 2 with their checks, the photo line, the chat and vitals lines, Night Operation's night line, a
  mode line before the handshake that never reaches Lua, an
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
  `member=` lines (the latest only), gone when she leaves the lobby. `solo_pair()`: our zone type or the pair's last
  one in a solo area, hers kept through 4 s with no vit line, forgotten at the session's end. The spot lines belong to
  one session: neither status shows one after a leave and a new join;
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
  cutscene pause, gift, race, follow, spot, rest, night or shared quest line either way), floods (no pong past 4 pings a
  second; a member over channel 0's 128 lines a second for 5 s refused by the owner and by a guest, who both stay, her
  session closed and no reject every 10 s; 200 lines at once not refused; pose data before any hello, over channel 1's
  limit for 5 s, refused; a guest leaving an owner who floods), the owner's round lines on a guest (a count line logged
  only when it moves her countdown, one notice for a start without her, past 8 a second dropped and logged once), the
  per-player chat mute kept for the run, per-peer pose caps (30 a second for a member of a match lobby, one peer's cap
  stepping down alone, one second of poses reaching peers at 20, 30 and 60 a second, tables always sent, an `SBE` sent
  to nobody as a match lobby has no pair) and the 60 s line of passes and full receive batches. Each of eight members'
  bike lines reaches the seven others, one state per sender. Score attack's lines in a match lobby of three go reliable
  to every member past the handshake. Each member's reaches Lua as `score <SteamID> <text>` with the SteamID from Steam;
  a text the line cannot carry never goes; past 16 a second either way they are dropped with one log line a minute; the
  counts have a line of their own beside the 60 s line, only in a minute that had some. Outside a match lobby a score
  line never goes and is never taken, with no log line. The Doro race's dr lines get the same cases with their own
  limit, drop lines and count line, which never touch the score line's. The dr line of a member with no handshake
  never reaches Lua. A match lobby carries no mode line either way, with no log line;
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
  the spot lines (a guest asks the host only, who drops her next ask within 2 s; his answer goes to her alone; the
  host asks one guest; a guest takes a `spot?` from the host only and an answer only from the member she asked, with
  her last id; the session's end forgets them); the rest lines (a guest sends hers to the host only; he takes one each
  2 s from each guest, drops one naming another member and relays the others once to every other guest, never back
  to the sender; his own goes to every guest; a guest takes rest lines from the host only, with no limit of her own
  in a session of 4); each member's ghost slot (`slot_of`) and the channel-2 lines waiting for her (`queued_for`); the
  SBA lines kept both ways when the pair leaves, as the shared quests' are;
  gifts (an answer to an earlier gift still going), Doro races, Night Operation and a guest's photo pause refused past 2
  players, the guest told so, while the host's cutscene still pauses each guest; the pair rule (the notice once on each
  guest who is not the pair and never on the pair, an `SBE` to the pair only and none from another guest, a channel-2
  line to one member reaching her alone with its sender, the pair leaving dropping the shared fight's lines both ways
  while the shared quests' lines of the guest who stays go on); channel 2 per member (Steam refusing one guest's lines
  holds back hers alone, the pair's going on in order past `kFightQueue`, hers reaching her in order once Steam takes
  them, each refused line counted once); `max_players` 3 on a guest's `host=` line and refusing a fourth player; the
  fishing tournament's mode lines in a session of three (reliable to every member past the handshake, guest to guest
  included, each reaching Lua as `mode <SteamID> <word> <text>` with the SteamID from Steam, a text the line cannot
  carry never sent, past 16 a second either way dropped with one log line a minute, the counts' own line beside the
  60 s line in a minute that had some, nothing sent with nobody linked);
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
  size: a port changes them (see [Porting](porting.md#the-port-step-by-step)). Her drone's block: its place relative
  to her main mesh, its light's step (none, hidden, another actor's light, capped at 127), her pose still read when the
  drone is gone (only its block hidden), an effect attached to the drone part in the effect slots, its box written only
  when it is the ghost's own. Her weights read from a leader or a follower's component (cut to 0 to 255 and counted,
  refused while an anim task holds them, past their count, null or gone) and written into a ghost part's morph arrays:
  by the map, with the mesh's morph count, the active list in mesh order without a null morph target, nothing written
  when unchanged, refused with nothing written when a capacity is short, SB emptied the active list or the mesh
  differs;
- `game_codec_test`: the codec's round trips, the deltas against a keyframe, a decoder fuzz and a 60 a second stream
  with every second delta dropped, which decodes whole; a free part's 25-byte block in a pose and in a delta's fixed
  part, a hidden block as 25 zero bytes; the four event slots, each a delta unit compared byte for byte, a refused one
  refusing the pose; the morph bytes after them, each a delta unit compared byte for byte, through the keyed pair too;
- `online_partner_delta_gain_test`: what the sender's delta tolerance (`kTolerance` in `game/codec.h`) saves. With no
  argument, as `tools/install.py` runs it, it encodes two synthetic recordings (idle and running) made by the real
  sender with no tolerance and with it, checks that the tolerance saves bytes on both and prints keyframes, deltas,
  their mean sizes and KiB/s for each. `build/host/online_partner_delta_gain_test path/to/coop-record.bin` measures a
  recording of the current protocol instead;
- `game_table_test`: the component table and the display file, with a parser fuzz, and the per-slot file names
  (`slot_file`); a free part (its free line, its size in the pose, the lines it refuses) and the display's six effect
  boxes and `free` box lines; morphs lines (a byte each in the pose, 256 a part, 512 a table, a follower's morph_read
  line in the capture file only) and the display's morphs lines (a remote morph per word, each index once, a leader's
  on its drive object);
- `online_partner_drone_test`: her drone's pick (the nearest within 3000 cm, a tie to the first) and when the lookup
  may run (both of SB's globals set, the world's manager and map found, game calls allowed);
- `online_partner_sound_test`: her sounds' slots swapped all or none (another mod's hook in one slot or a page that
  will not become writable gives back the ones taken; unrelocated originals never match) and back; the three sets
  apart; the world-effect set (Niagara's and Cascade's start slots, one refused gives the other back); why a sound is
  hers (mark, owner, attach, none); nothing recorded while the viewer plays or off the threads
  with a ring; the ring of 64 (a later start of a component under one mark replaces its record, the 65th is lost and
  counted); a show stage's main actor; the asset key's attenuation mixed with the int parameters; a record's SBA words
  from a fake name pool (a class outside SB's folders goes as `-`, a parameter name that is not a word is left out, a
  sound not at the top of its package or outside SB's folders is refused, as is a line that passes 512 bytes only
  under key 4096); a world effect's SBA words (`niagara` or `cascade` with its path and `- -`, refused outside SB's
  folders); an event on a part the table no longer has goes empty; the viewer's `is_asset` (an object still at its
  path in any case, not one that took its address, not a namesake in another package); `loops`, SB's one-shot rule for a
  sound at 10000 s or more (a NaN plays, as in SB); the viewer's `compose`, which puts an event's place back on its
  parent where her game played it (2000 random transforms, a scaled parent among them);
- `game_events_test`: `game_calls_ok`, which allows a game call only with the lion gate open, the client in game and
  playing, off SB's logic thread; an event slot's 19 bytes with a fuzz (each slot it accepts encodes back to the same
  bytes); the `Outbox`, whose events wait at most 100 ms and hold a slot for 2 poses and 50 ms plus one send interval,
  so a member capped at 20 poses a second sees every event; the asset keys, one per name, kept after a reload, none
  past 4096; the SBA line with a fuzz (each line it accepts formats back to the same text), its paths (SB's own only)
  and its 512-byte cap; the name book a member who comes in later reads from her cursor at 8 KB a second and while her
  channel-2 share has room; a slot's names (a key's second line refused, the same line again let through); the slot
  watch that forgets a slot's names when its member changes or a session starts or ends; the `coop-loaded` lines; the
  viewer's `Gate` (8 a second from one ghost and 32 from all in any second, the nearest first, none past 50 m or in a
  scene), `ghost_shows` and `NameWait` (a key's name waited for 200 ms at most, 16 events per ghost);
  `skip_attached_niagara`, which skips only a Niagara start the effect slots carry (a listed system of the capture's
  class hung on one of her leaders); the effect kinds' slots, each round trip;
- `online_partner_resend_test`: our component table's resends (`TableResend` in `game/table.h`) on a worker passing
  every 50 ms: at once to a new friend, then 5, 10, 20, 40 and 60 s apart, every 60 s from then on; a change brings the
  next one 5 s after it and starts the doubling over; a sign her side lost our table brings it within 5 s, and a flood
  of them sends one each 5 s at most;
- `online_partner_record_test`: the recording's reader, with a fuzz, and its replay, with same-place enemies' `SBE` and
  show lines re-stamped on the poses' clock;
- `game_stream_test`: the loopback pipeline in simulated time, and the playback of a match lobby member who gets every
  2nd or 3rd pose of a 60 a second stream (cap 30 or 20): with 100 ms of lag she is drawn 150 or 175 ms back; a free
  part's place blended between two poses that show it, with the newer pose's state; a morph's weight blended between
  two poses and cut to a byte past the newest; the events a ghost plays (each slot's serial once, none from the poses a
  playback starts with);
- `online_partner_inbox_test`: the game thread's pose inbox (`kInbox` in `game/core.h`) in a full match lobby, 7 members
  sending 60 or 30 poses a second: one game-thread stall of 102, 198, 291 or 361 ms (the stalls of steady play
  in the 2026-11-12 log) drops no pose and leaves no delta without its keyframe;
- `online_partner_gap_test`: the native tick's gap line (`gap_line` in `game/core.h`) from fixed values: the UTC time of
  day out of a FILETIME (the last 100 ns of a day included), the gap in whole ms, a frame past 32 bits, the tick before
  it, and the `vkd3d-proton.cache.write` growth, left out when there is no such file;
- `online_partner_bench_test`: the ghost bench's native core (`online/partner/bench.h`) over its own fake object array.
  `coop-bench.txt` read against her table: off, stale for another generation or with no capture, an empty list (the
  baseline), offsets of 300 m, a display that does not parse left out and counted, the phases of strides 2 and 4,
  malformed for a bad head, a block line that is not `ghost` and three whole numbers, stride 0, 3 or 8, an offset past
  30000 cm, a 65th block or a file over 4 MiB. A pass's read of a missing file: off before a run, kept during one. Her
  loop: nothing before her first read, the frame just added drawn while recording (again after a refused read), then the
  240 frames in order from the first again. A new list swapped in (`bench_swap`, which `bench_take` calls): the first
  one, one on the same capture that keeps her loop, one on a new capture or with other leaders' bones that records her
  again. `bench off` gives the old list back. One pose written into a bench ghost: its leaders' bones and refresh bytes,
  the mailbox at her root plus the offset with the stamp, a remapped leader, a closed gate refused with its part while
  the rest is written, the first refused part named, a mailbox of another actor refused as the mailbox, a destroyed
  root part gone with nothing written or counted, a left-out leader's bytes skipped.
  `bench_due` for stride 4 and phase 1. The exact `coop-bench-out.txt` lines with the memory, without it and empty;

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
- `world_maps_sboxion_sboxion_test`: SBO Xion's two guards (`world/maps/sboxion/sboxion.h`), one case for each guard.
  For `coop xion`: the client made, co-op saves, an entered slot, in game, playing, no warp, no camp request, no
  reload, client `+0x100` at 0, the logic actor, no theater, photo mode off, a current zone not of type 3, 5 or 6,
  no Boss Challenge byte, the asked zone's row, its type 5 and its world row. For `coop xion leave`: the zone
  compared with the client's (another zone, another FName number, none asked), then the same flow guards, the
  theater, photo mode and the reload's two other sources. Then the answer word's round trip, the `sboxionwarp=` line
  and the log lines. Then the inside flag (an accepted enter sets it, an accepted leave clears it, a refusal keeps
  it) and the line's `life=` word: on the entered, refused and fault forms when the read worked, never on the off
  and left forms;

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
    - SBO Xion's 2 rows (`world/maps/sboxion/sboxion_rows.h`) added from their templates, the world row before the
      zone row that names it, with IDs no hall row holds; a taken zone ID stops the batch after the world row;
  - the refusals that call no AddRow (a missing template, a taken ID or name, a wrong vtable, AddRow slot or row size);
  - a later run skipping the rows already in, FName's number split, the read-back through the game's lookups by ID, the
    answer word, the `lion=`, `gardener=`, `tendril=`, `bolt=`, `mxiii=`, `shop=` and `signal=` status lines and the log
    lines;
- `rows_shock_test`: the Shock Bolt's two lists against fake memory: both gun stances given the two fire commands
  (through the game's grow or inside the capacity), the const ammo list and the slot manager's list given
  `Bullet_Shock`, a second run writing nothing, no slot manager yet, the key found down its hash chain, each refusal
  writing nothing, an allocation that fails, the answer word, the `shock=` line and the log line;

### Shared enemies

- `fight_enemies_push_test`: enemies at her ghost (`fight/enemies/push.h`). SB's step out of a ghost's body: 100 cm/s
  (750, or its lead when larger) times the delta, never past the free place, at most 100 cm out, horizontal; nothing
  when touching, above or below her, on one vertical with her, with a delta of 0 or a NaN anywhere. The ghost's body
  from the drawn root (98 cm up her main mesh, turned and scaled). The frame's gates. SB's rule of who moves: same
  weight by rank and motion, the lighter of two weights, each of the enemy's own bytes that stops it;
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
- phase 3's boss fights:
  - `game_boss_rows_test`: `game/boss_rows.h` on build 26123051's rows: the counts (25 triggers on 14 spawn rows, 10
    QTE, 15 `LV_Dead` rows), Raven's two triggers in table order, the QTE rows of the Raven Beast, the Elder's first
    phase (none), ExoSuit (two), Opener (its trial row is none) and a brute whose trigger plays no scene; then
    `by_scene`, `crosses` on both sides of a threshold (none for a percent trigger with no MaxHP read) and `lv_dead`;
  - `fight_enemies_spectate_test`: `fight/enemies/spectate.h`'s rules with no game: each enter rule alone keeping it
    off, the Coma press (Left on the Coma screen starts it, Top never does, taken at the next step only), one respawn
    reason at a time counted once, a copy that died in Coma, each leave (nobody, ended after 10 s of running fight,
    link, off, revive 4 s after a reason) with its one release (1 at life 3, 4 at life 2, none at life 4), life 6 as
    up, one spectate per down, a pause that counts nothing and reads no reason, the hold and swallow cases of Review
    Focus 1 and the button map;
  - `game_fight_sync_test` adds the `bosses <first|host>`, `fin`, `qte-own` and `spec` lines through format and parse
    (a bosses line with no fourth word read as host); the host's claims on its bosses while its EVE is down (kept while
    a member stands, dropped and logged once a down with nobody up); the HP scene hold on both sides (held in order,
    let go when our EVE is up or after 2 s, never for a trigger with no scene, dropped with her claims at her on, a
    repaired copy holding for its own 2 s); the first press (hers winning past aggro and same place, ours first in
    one turn, our press after hers refused once, her press waiting 1 s for the Finish stance, `host` mode, one `fin`
    a winner, sent again after the up lines at her on); the QTE owner (the claimant, our own hit, hers in a shared
    turn, the next member up, nobody up, each miss to the next member, story together off, once a boss, sent again
    at her on); a boss line taken only from the pair's owner; the guest's reads of `bosses` and `fin`;
  - `fight_enemies_engine_test` adds the boss claims judged on the vitals that came before them in one drain, a Coma
    member read as up, spectate's facts and the phase signature, the pit relocation once after a spectate revive
    only, the live `fight=` words, the finish guard waiting for `fin` on the guest, the guest's finisher exec past
    the gates, the host's guard after her win and her off forgetting it, `fin=` and `qte=` on the line, the QTE owner
    from her vitals (Coma or stale read as not up), the `qte_on` and `qte_end` messages, the boss hand-overs and each
    busy reason (Finish stance, a phase change in the last 3 s, a story scene, a named QTE owner or finisher), the boss
    pilot's gate, boss lines from the owner on both sides and her summon keyed by her member on the host;

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
- `online_modes_race_hold_test`: the Doro races' hold on EVE (`online/modes/race/hold.h`) over a fake memory of two
  movement components and two meshes: the four fields kept and set to 0 while the hold is asked, one the game writes
  again set to 0 and counted, the kept values back at the ask's end; the tick option the same way with its re-sets
  counted; neither applied without EVE or while a scene stands still, both put back as such a scene starts and applied
  again after it; a pause that changes nothing; a map change dropping the kept values unwritten when the old object is
  gone and putting them back on it when it still lives; `coop off` and a new Lua load putting everything back; the
  offsets as read in Ghidra;
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
  what each frame does; the bike's `ride` play (a loop forever with foot IK type 2, held with argument 17 at 1 and
  `kRidePriority` between 100.0 and 101.0) and its foot IK put back as SB's stop does once the ride's play is over;
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
  `unread`, never in a hang. A read's log line comes only when its alias's answer changes;
- `online_modes_fishing_fishing_test`: the fishing tournament's book read against a fake image laid out like the pinned
  build (the logic singleton, its actor map, the logic actor, its FSBActor and the book's set with its hash chains):
  every fish IDs ascending over chains with collisions and the engine line's answer, an empty book, `noeve` (no logic,
  a GUID of 0 or not in the map, an actor of another vtable or GUID, a 0 alive byte, no FSBActor), `nobook` and
  hostile memory ending in `unread`, never in a hang or a wrong list (an actor map whose chain loops or leaves its
  array, a book of another vtable, a bad hash size, an inline hash of more than one bucket, a chain that loops or runs
  longer than the count, an index past the array, an ID outside its bucket, not above 0 or found twice, a torn count,
  unreadable elements);
- `online_modes_photohunt_photohunt_test`: the photo hunt's photo check over a fake game: no ask, not the selfie
  camera, no photo UI node, a node of another vtable, a shot byte of 3 on a new object (only recorded), 0 to 3, 3 held,
  3 to 0 to 3, a null row, the row's lazy init made once and never for a row SB set up, the answers in order, a map
  change (another photo UI object and a row that reads null, then the next shot counting again), a result outside 0,
  1 and 3, a new ask starting at no shot, the answer's text and the engine line's field (`none unpinned`, `none off`,
  `none fault`, an ask not taken yet);
- `ui_pad_test`: the controller's events for the co-op menu (each press, up and down repeating while held, a D-pad
  diagonal read as up or down and the stick along its main axis, which keeps its pressed axis near 45 degrees, the
  stick's thresholds, View held 1 s, D-pad Right held 1 s for the bike, LB, RB and Y once a press and in event order
  with up's repeat going on, a disconnect, the event queue), which XInput slots each poll asks, `PadKeys` (a held
  button in every read until its release, a press and release inside one poll counted once, a repeat ignored, two
  controllers ORed, the stick pushed furthest, clamped values, unknown keys and ids outside 0 to 7 ignored, `clear()`,
  the events from `PadKeys` as from XInput), Slate's handler slots pinned to the vtable and the Online tab's event
  posted into the queue in order with the pad's, a full queue dropping the newest; the emote wheel's reads: the right
  stick's sector (0 inside half its range, 1 to 72 clockwise from up), D-pad Left held 300 ms making event 13 once a
  hold (not at 299 ms, again after a release, forgotten with no pad), the right stick from XInput's slots and from
  `PadKeys` (the controller pushed furthest, `clear()`);
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
  one that never ran: stuck). Then the spot warp's record and its bytes (our GUID, the fade, the place and the yaw; a
  world's FName only from `coop travel spot <world>`), the spot guard (no camp name; `Why::solo` refused after every
  other guard, never for a camp travel) and `Rests`, the count of zone reset starts (one per start of type 1 or 2 held
  over several reads, ours by our GUID, type 0 not counted, SB's echo with GUID 0 never ours);
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
  the receiver rule for host and guest (a state held out for us kept, nothing sent back), her `s` line kept the same
  way for a passcode door typed open (live or in its record) and applied when ours is untouched, in a kept pair, not
  read or without an entry in the line's zone, a `c` line older than a root of ours kept (her answer or her
  send-back), a `c` line applied as a state then an Enable or Disable, the host's value sent back, a close in the
  middle of an answer, the walk's filters, one answer per ask, the ObjectState compare and a partner that never
  answers;
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
- `game_story_sync_test` adds phase 3's leader per scene: the guest leading Raven's QTE scene with the host following,
  a line for a scene no Leader names refused, the hold at the first QTE block (until a Leader or her lines, 5 s at
  most, given back when story together goes off or a new partner comes), a stale leader's line refused, a miss
  clearing the leader until the next try, a lead that comes mid-scene, ExoSuit's two paths, a boss scene that waits
  while our player watches the fight, the ended QTE scenes reported once and the QTE hook's result sent only while
  we lead.
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
  Phase 3 adds her() telling a QTE or InputCounter block of the playing theater still open (its result slot below 0).

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
- `boss_rows_test.py`: `tools/boss_rows.py` on small made-up tables, without the game's: each filter (rank, test, demo,
  NIKKE and Boss Challenge rows, a condition that is no ActorHP, a condition with no event at its index, an equation
  other than LEQ), the scene a trigger's event plays (through AddEvents, a level sequence alone, a Stop row, an
  effect-only chain), the QTE flag on the exact theater alias and the LV_Dead rows. Then the written block: parsed
  back to the same values, within its markers, the rest of the header untouched, a name that cannot go into a C++
  literal refused. Last, its load and main over a folder of table exports;
- `install_test.py`: `tools/install.py`'s install, backup, uninstall and zip, on a fake game folder, and its `--pak`
  part: the copy of the three `zSBO_Lobby` files into `~mods` with a backup of the ones it replaces, a copy that does
  not hash like its source, a folder that lacks one of the files, the dry run, the refusal while the game runs, and an
  uninstall without and with the mod folder (the pak first, each into its own backup folder), all of them leaving the
  rest of `~mods` and `LogicMods` alone. Its `--ue4ss` part: SBO's UE4SS package over a 1.3 install (the backup, the
  signature scripts the package lacks and `Changelog.md` removed, the player's ConsoleEnablerMod replaced after its
  backup, the player's `mods.txt` and other mods kept), into
  a folder without UE4SS, the dry run, the refusal while the game runs. `install.py --help` runs under `python3 -I`,
  as the gate runs it, so `install.py` finds `tools/ue4ss.py` itself. `main` with `--ue4ss` refuses `--zip` and
  `--uninstall`. It stops before the tests on a missing executable, on a build with no set, on a missing `UE4SS.dll`
  build, on a `UE4SS.dll` of other bytes and on a cached zip of other bytes. Its dry run and its install say the mod's
  lines, then the UE4SS lines. The tests it runs side by side write their output in their own order and stop at the
  first failure. A native test is built again only when its source, a file it includes, the flags or the compiler
  changed;
- `ue4ss_test.py`: the files under `ue4ss/`. Each build set is named after its executable. The set's signature scripts
  run under `lua5.4` on made-up matches and, when this PC has Ghidra's copy of build 26123051, on its executable. Its
  `VTableLayout.ini` gives the offsets read in Ghidra. Its `MemberVariableLayout.ini` holds only values read there.
  `UE4SS-settings.ini` holds every key of the v4.0.0 file with SBO's values. `NOTICE` credits the sources, the fork's
  `[EngineVersionOverride]` setting among them. It keeps the release files' MIT license for the package. Then
  `tools/ue4ss.py` on made-up executables and a made-up release zip (a download reads a `file://` URL): the set picked
  by the PE header, a file that is no 64-bit executable refused, an unknown build stopped before any download, a
  download or a cache file of other bytes refused and never cached, a missing `UE4SS.dll` or one of other bytes refused
  before any download, the package's files and the zip's paths with no `mods.txt` but an `enabled.txt` for each mod it
  turns on, written twice with the same bytes. The package's `UE4SS.dll` is the built file, never the release's. The zip
  takes a `UE4SS.dll` given on the command line in place of the default one. SBO's `UEHelpers.lua` is loaded over fakes:
  two calls to `GetPlayerController` or `GetWorld` make one search, a controller gone is searched for again. When this
  PC has the pinned release zip, the settings and the package are checked against it, ConsoleEnablerMod's `main.lua`
  byte for byte. Every release file the package keeps, `dwmapi.dll` included, is the release's byte for byte. Its
  `UE4SS.dll` is not the release's. When this PC also has SBO's `UE4SS.dll` at the default output of
  `tools/ue4ss_build.py`, the package's DLL has the pinned SHA-256. Without it, a made-up DLL stands in and the output
  says the real check was skipped;
- `ue4ss_build_test.py`: `tools/ue4ss_build.py` without network, Git or the toolchain. The one file in `ue4ss/patches/`
  is `git format-patch` output of commit 9a61a393 with its subject, the issue link in the note below `---` and diffs of
  `LuaMod.hpp`, `LuaMod.cpp` and `UE4SSProgram.cpp`. A tag that is not commit `30afe5ff` is refused. So is a patched
  source that is not commit `4c8e4f4d`. `git am` keeps the author's date as commit date. It runs with the patch's author
  as committer and with no user or system Git config. It checks the clone, configure and build command lines (the
  `UE4SS` target only) and the variables that map local folders and pass `/Brepro` to the linker. The default output is
  the path `tools/ue4ss.py` reads. Over a fake `subprocess.run`: a used work folder, a path with a space, extra
  arguments, a missing tool and a missing xwin folder stop it before any command. A moved tag stops it after the clone.
  Another patched commit stops it after `git am`. A whole run calls clone, tag check, `git am`, patched-commit check,
  configure and build in that order and prints the DLL's hash against the pin;
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
  file's guard or adds another request (`ServerRequest_ActorRevival`) fails the scan. Spectate's
  `fight/enemies/spectate.lua` holds 7 mentions of `ServerRequest_` (its `ActorRespawn` and `ActorRevival` on our own
  EVE, a copy of group play's respawn, with their log lines, `coop spectate test`'s respawn and the header's two):
  another request planted there (`ServerRequest_ResetZone`) fails the scan. SBO Xion's
  `world/maps/sboxion/engine.lua` holds its one `ServerRequest_ActorRespawn` on our own EVE and its header's mention,
  and `world/maps/sboxion/recover.lua` holds that call's log line and its header's mention: another request planted
  in either file fails the scan.
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
  executable other than the pinned build is refused. `main`, on that file pinned in place of build 26123051, writes
  `signatures.json` and `tools/port/ue4ss.json` from one build. The first takes the code's names. The second keeps its
  own. An address in both gets the same signature in each. A `ue4ss.json` of another build than `signatures.json` is
  refused before either is written. The two files in the tree name one build. Every entry of
  `tools/port/signatures.json` that needs a signature has one in the form the tool writes, with the names the code
  gives its address. So has every entry of `ue4ss.json`, whose names are FText_Constructor, GNatives and GUObjectArray.
  Then
  `tools/port/find.py` on the same PE file: every entry is found, the image base and a section included. With a
  function added before the others, the code addresses move by 16 bytes and the data addresses stay. Three copies of
  a function give `ambiguous (3 matches)`. A holder's code held in two places gives `ambiguous (2 matches)`. A
  function removed gives `missing`. So does a `read` that lands outside the file. The exit code is 1 for each.
  `find.py`'s UE4SS signature scripts run under `lua5.4` with a `DerefToInt32` that, as UE4SS's, gives nil for 0: a
  function's own run, a `ref`, a `ref` with an `add` and a `ref` with `then` each match once in the whole file and give
  their address, the moved one in the build with moved code. No script comes from a `holder`, a `read`, a signature
  found twice or not at all, one that also matches in `.rdata` or one that matches in `.rdata` only. Its UE4SS report
  prints a script for each target or the line `no script.`, with exit code 1 for the latter. `find.py`'s main prints
  that report after the one of `signatures.json` and exits with 1 when a target gets no script.
  Last, `find.py` on `~/Ghidra/stellar-blade/input/26123051/SB-Win64-Shipping.exe`, Ghidra's copy of build 26123051:
  every entry of both files is found at its own address. Each UE4SS target's script matches once in the whole file
  and gives the address read in Ghidra (FText constructor 0x142862fc0, GNatives 0x146f17900, GUObjectArray
  0x146ddd240). A PC without that file skips this part and says so. A port points `EXE` at the new build's copy (see
  [Porting](porting.md#the-port-step-by-step) and [SBO UE4SS](ue4ss.md#adding-a-build));
- `release_test.py`: `tools/release.py`'s build, upload and publish steps and its refusals, with git, gh and
  `tools/install.py` faked;
- `save_read_test.py`: `tools/save_read.py` on GVAS bodies built in the test (the header, values, containers, the EVAS
  wrapper's checks, the byte-or-name guess, value paths) and its commands on saves in a temporary folder;
- `cns_coop_saves_test.py`: `tools/compat/cns_coop_saves.py` on a stand-in for CNS's `main.lua` written for the test,
  with its own hash and insertion lines. No line of CNS is needed. It covers the apply with its backup, a second apply
  that changes nothing, the remove back to the same bytes and the check of each state. A file of another hash is
  refused by each command. Apply and remove refuse while the game runs. A remove after a line of the stand-in changed
  restores the shipped backup, or refuses without one. Then the stand-in with both blocks runs in Lua 5.4 on temporary
  saves: solo save only, co-op copy only (the fallback), both (the union, the first path put back), neither, the cache
  reset. On a PC with CNS v2.2 installed, a copy of its `main.lua` goes through apply, a Lua load and remove. Without
  it, the test says so;
- `story_lines_test.py`: `tools/story_lines.py` on an invented 29-line example with a known digest, on
  `story_case.json` against `story_case.txt`, on what must leave the digest alone, and its commands on saves and dump
  files in a temporary folder. It also checks `float_repr.txt`, Python's `repr` of 2,331 doubles for the Lua side;
  `python3 tests/tools/story_lines_test.py --write` writes it again;
- `windows_test.py`: `install_test.py`, `save_guard_test.py` and `story_lines_test.py` in a Python set up as on Windows:
  text files and subprocess text in cp1252, `\n` written as CRLF and no `signal.alarm`. Symbolic links are first
  refused with WinError 1314 (Windows without Developer Mode), then allowed where this machine can make links. Without
  them, `install_test.py` and `save_guard_test.py` print a `not tested` line for each check they skip. Paths keep the
  separators of the machine that runs it.

## Grouped game test: travel, camp rests and solo areas

These rows need the game on two or more PCs. Every PC runs this build (protocol 29). A PC on a protocol-28 build is
refused at the hello. Read `UE4SS.log` and `coop-link.log` on every PC after each row. None of these rows has run yet.

1. Same map, over 150 m apart: the offer shows. F7 puts the guest on the host's last ground point after the game's
   fade. Her `activated=` line's `rested=` stays the same.
2. Same map, 20 m apart: F7 works. Within 5 m: refused, one log line (`the host is within 5 m`).
3. The host jumps, climbs or swims at the press: she lands on his last ground point. No ground read for 10 s: the
   `air` notice.
4. The host on another map: the camp travel, then the spot warp with no second key press.
5. The host rests in the zone they share: the guest's zone resets once (`area=`, `rest=` and `starts=` on her engine
   line before and after). Same spawns follows. The guest rests there: the host's zone resets once. On the receiver,
   note the screen and the controls during the reset: a fade, a load screen, input blocked or none of these.
6. A member in another zone of that map: no reset (`rest: our area is <zone> (... dropped)`).
7. The guest in a fight during the host's rest: her reset after the fight, or the skipped notice after 60 s.
8. One `ServerRequest_ResetZone` call: count the `zone reset start` lines in the receiver's `coop-link.log` in the
   next 30 s. Expected per call: one `zone reset start: type 2 guid 0 another in <zone>` line. More than 3 trip the
   stop latch. Note the receiver's screen and controls as in row 5.
9. The host enters a Boss Challenge (Xion's Raven Beast), later the training room: the notices; F7, the revive and
   the way back refused; no shared enemies or scenes with him (`online play paused toward the pair: a solo area` on
   both PCs); his EVE hidden; `is back` when he leaves.
10. The guest dies with the host alive on her map: the notice, F7, up in place, then next to the host. No zone reset.
    Recovery items refilled. The host dies with the guest alive: the same toward her.
11. A death in a kill volume: a second death within 10 s gives the game's own respawn only.
12. `coop travel spot <world> <x> <y> <z>` across worlds, solo: where she lands, which zone, the respawn camp
    unchanged.
13. A spot warp onto a lift or a train the host stands on: where she lands.
14. Three players: guest 2 follows the host. Guest 1 rests: the host's zone resets. Guest 2's zone resets only when
    she is the pair. Outside the pair she has no shared fight yet: she logs `rest: no fight read in this game (...)`
    and keeps her area. Then four players rest at one camp together: one reset in each game, no stop notice.

## Solo probe: spectate

`coop spectate test` checks spectate's game parts on one PC, without a friend. It needs a co-op save, no online
session, `coop loopback 0 0 0` running (so that your life state is read) and your EVE on the game's Dead screen (life
state 3). Back up the save first: the respawn refills your recovery items in it.

1. Let EVE die, wait for the death screen, then type `coop spectate test`. The answer is `spectate test asked: its line
   follows in this log in 12 s`.
2. The death screen hides from the next frame and a camera looks down on your EVE from 4 m up.
3. 10 s later the mod asks the game's in-place respawn. 2 s after that `UE4SS.log` says `[StellarCoop][SP] spectate
   test: hud <before> -> <after>, life <n>, camera <ours|pawn|other>, respawn <asked|refused: <why>>`. Expected: `hud
   2 -> 0` (or `1 -> 0`), `life 1`, `camera ours`, `respawn asked`, with EVE up where she fell.
4. `coop-link.log` has `spectate filter on: 0x145c34250 swapped ...` once a run. `coop spectate status` afterwards
   answers `spectate: native on, hud -, not watching, camera pawn`.

A `refused` result names the respawn's blocker (a warp under way, the Night Operation probe's rule, a game that is not
standalone). The native part gives the death screen back after 14 s at most if the respawn never comes.

## Solo game test: emote wheel and test tools

One PC, a co-op save, in an open area with no enemy near. Read `UE4SS.log` after each row. None of these rows has
run yet.

1. Hold F2: the wheel shows at the screen's centre. Move the mouse: the camera stays still and the slot under the
   pointer lights. Release F2: EVE plays it. `UE4SS.log` has `[StellarCoop][EM] wheel: open on Greeting (F2)` and
   `wheel: emote <name> (release)`.
2. Q and E change the page, a right click goes to the next one, Esc cancels, a left click plays. Tap F2: nothing
   plays.
3. Controller: tap D-pad Left (the game's action still happens), then hold it 0.3 s: the wheel. Point with the right
   stick, LB and RB change the page, release D-pad Left: the emote plays. B cancels. Walk and guard afterwards: no
   button stays held.
4. Hold F2 in the air, on the bike and in a fight: no wheel, the notice `No emote now: EVE is busy.` Open the wheel and
   let an enemy hit EVE: it closes. Alt-tab with it open: it closes, nothing plays.
5. Set the game to German: the slots show the game's German names. Set `ui_language=english` and `ui_scale=150`: the
   mod's English names, the wheel still on screen.
6. F5, TEST TOOLS, EVE's cut moves: Debug flight On, close the menu and fly, then Off. On a main save the row stays Off
   and the note says why.
7. Developer menu: No damage On, take a hit, then Off (every lasting switch reads Off). Full health. Developer panel
   Quests, close the menu to see it, then Off.
8. Cut models: Leviathan, body, Show; close the menu and fly the free camera; Free camera Off; Remove.
