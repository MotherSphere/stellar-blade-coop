# Gun mode

Gun mode gives EVE the NIKKE DLC's rifle outside its missions, on any save, as a third-person shooter. It is
experimental: it has been played on one PC only, not yet between two players.

## Parked while it is rebuilt

G (`gun_key`) or a tap of D-pad Right shows the notice "Gun mode: rebuilding" and does nothing else: no table field
changes, no rifle comes out. The park lifts when the game finds the rifle layer's class `ABP_NGM_Spike`
(`/Game/Mods/NGM/`), which comes in the optional pak `zNGMSpike_P`. With that pak installed, the key brings the rifle
out as the rest of this page describes.

## The rifle layer

When the rifle comes out, `fight/gunmode/overlay.lua` swaps her body mesh's post-process anim blueprint for
`ABP_NGM_Spike`. The layer works on her finished pose. It plays one of the pak's poses (`Mods/NGM/Poses`) on her arms,
hands and head (from `Bip001-Neck` down): `CarryLowReady` while she carries the rifle or reloads it out of firing mode,
`AimLevel` in firing mode, a reload included (`AimUp45` or `AimDown45` past 22 degrees of rifle pitch). It also runs
her outfit's own post-process graph. Her main animation, springs and outfit physics are left as they are. A pose that
the installed pak lacks (an older `zNGMSpike_P` without `Mods/NGM/Poses`) is looked for once per Lua load. The layer
then keeps the pose it plays. `UE4SS.log` has one line such as `layer clip aimup: clip not found aimup`.

Each frame `fight/gunmode/ik.lua` places the rifle in her mesh's component space: on the camera's line in firing mode,
at low ready otherwise. It puts her right hand on the rifle's grip and her left palm on the handguard. The rifle is
attached to her real right hand (`fight/gunmode/rifle.lua`) with the grip of the pose on the layer. When the pose
changes, her hands and the grip ease to the new place together, so the rifle never jumps in her hand. The ease is
exponential with a time constant of 0.14 s: 63% of the way after 0.14 s, 97% after 0.5 s.

During one of the game's own moves on the ground (a dodge, a hit reaction, a knockdown, a parry) the layer plays the
carry pose until the move ends, in firing mode too. The aim's turn of her body eases out meanwhile. In the air the aim
pose stays while she aims or fires. A new outfit drops the layer: gun mode puts it back within a second, or puts the
rifle away when it cannot. When the rifle goes away, each body mesh the layer went on gets its own post-process class
back.

`UE4SS.log` has the `[GM]` line `rifle layer on`, or `rifle layer not available:` with the reason. When the layer
does not install, gun mode falls back to the rifle clips alone if the game finds them (`animation pak found`): the aim
stance's animation set then points at the rifle's blend spaces. Without them it falls back to luke77's posed stance
(`animation pak not installed: posed aim`), which shows a posed copy of her body on your own camera.

## The pak

`zNGMSpike_P` is not part of SBO. SBO ships no animation file. The pak is built on your own PC:
`tools/gunmode/rebuild/ngm_spike_build_a4.py` cooks an Unreal project (`SBOutfitProject`) that is not in this
repository. It packs `Mods/NGM`: the layer, its four poses (`Mods/NGM/Poses`) and the aim camera's modifier
`BP_NGM_CamMod`. It adds the `NGM_R_` clips when the environment variable `NGM_REL` names their folder. No script in
the repository makes these assets or the project. [Gun mode tools](../../tools/gunmode/README.md) lists
what each script makes.

## What gun mode changes in the game's data

While the rifle is out, gun mode changes a few fields of the game's own data tables in memory, plus one field of the
NIKKE shot's show. These changes add no row. Everything it changed goes back when the rifle is put away or at the next
map load, so the NIKKE missions and the drone find their rows as shipped. The rounds' rows are apart from these: they
go in once a co-op save has loaded and stay for the game run ([The rounds' rows](#the-rounds-rows)). The fields the
rifle changes:

- `EventActorEffectTable`, `EffectTable`: the NIKKE shot, started from a borrowed row. The game's own tables use these
  two rows too (a NIKKE mission's zone event, the Scarlet fight's counter). They change only from a shot that needs
  them until 1 s after the last one.
- `SkillCommandTable`: the NIKKE fire commands take the burst shot's command type, which checks no equipped round.
  With `gun_fire=native` (the default) every drone fire command starts the NIKKE shot too, also in a jump.
- `SkillTable`: the NIKKE shot's cool time. It is the rate of fire (0.045 s), the reload's wait during a reload and 999
  once every magazine is spent or while an off waits for the game's aim to end ([Firing mode](#firing-mode)). SB keeps
  its own copy of the cool time from each shot's start and counts that copy down. It refuses a shot while the row's cool
  time and that copy are both above 0. So the rifle out, the end of a reload and a refill of the magazines write 0. One
  cool time and at least 4 frames after the first round (the game's aim or gun mode's own) the row holds the rate of
  fire again. The 4 frames cover a slow frame or 30 fps, where SB's first start can come after one cool time. Without
  the 0, every magazine fired dry with the trigger held left SB a copy of 999. The next rifle out then fired no SB round
  and no shot sound for up to 999 s, while gun mode's flash, recoil and count went on. A reload's wait copied the same
  way held SB's rounds back for a moment after a reload with the trigger held through it.
- `SkillActiveStepTable`: the shot's `Hit1` step takes the `Type` of its `Cast1` step. It fires its projectile and
  spends no round.
- `EffectTable` `P_Eve_GunNikke_ReloadCompleted`: SB's own NIKKE reload adds no rounds to her bag, in both fire
  modes. As shipped, its `Action1` adds 60 `Bullet_Nikke` about 1 s after the last NIKKE shot while EVE carries fewer
  than 60. While the rifle is out the action is `EffectAction_None`. Gun mode's free magazines do not use
  `Bullet_Nikke`. The action goes back 3 s of play after the other rows (paused time not counted), with the rifle away
  too. SB reads it when the effect starts, about 1.07 s after its last NIKKE shot. Put back at once, an off right after
  a shot gave 60 rounds. `coop off` puts it back at once. Gun mode keeps no file of these fields: a Lua reload during
  the 3 s leaves them held until the game restarts. `UE4SS.log` has the lines
  `data: P_Eve_GunNikke_ReloadCompleted Action1 22 -> 0: SB's NIKKE reload adds no rounds` and
  `data: P_Eve_GunNikke_ReloadCompleted Action1 back to 22`.
- `EffectTable` `P_Eve_GunNikke_BulletZero` and `P_Eve_GunNikke_Reload`: no NIKKE cover stance and no NIKKE reload of
  SB's own, in both fire modes. Every gun mode shot is SB's NIKKE shot. Its `P_Eve_GunNikke_SkillUseCheck` chains
  `BulletZero` and `Reload`. Gun mode's free magazines add nothing to `Bullet_Nikke`, so her count can be 0 after a
  shot. As shipped, `BulletZero` then starts at 0 rounds. Its stance `P_Eve_GunNikkeHide` is the NIKKE cover stance,
  low with the rifle down. Its end condition is `Bullet_Nikke` above 0, so she stayed in it.
  `P_Eve_GunNikke_ReloadCompleted`'s `DispelFlagsArray` also names `P_Eve_GunNikke_BulletZero`. Whether that name
  matches the effect's flag (`Nikke_BulletZero`) was not read. `Reload` plays SB's NIKKE reload show on her whole body.
  While the rifle is out the item check of `BulletZero` needs a count of -1 and the one of `Reload` a count below 0. No
  count passes, so SB applies neither. The two `ConditionActive_ItemCount` fields go back with the refill field, 3 s of
  play after the other rows. At `coop off` all three go back at once. A shot SB is still running at that moment can
  then start the cover stance. SB's own refill of 60 rounds ends it about 1 s later. `UE4SS.log` has the
  lines `data: P_Eve_GunNikke_BulletZero ConditionActive_ItemCount 0 -> -1: no NIKKE cover stance at 0 rounds`,
  `data: P_Eve_GunNikke_Reload ConditionActive_ItemCount 60 -> 0: no NIKKE reload of SB's own` and the two `back to`
  lines.
- `ProjectileTable`: the round leaves the rifle's muzzle for the crosshair point. Its destination is an offset from
  EVE's root in her root's frame (`DestTarget` MainActor). The shipped `StartToDestDirection` aimed along SB's own
  target line and sent the rounds to the side. `UE4SS.log` has the line
  `data: NIKKE round: dest target 3 -> 0, start target 0, start-to-dest distance 50000.0` at the rifle out. Its own
  spread (a random range of 300 cm) is off. Its destination is placed once, when the round spawns, not again while it
  flies.
- `CharacterStanceTable` (with `gun_fire=native`): the aim stance is faster. A jump does not end it. The aim plays no
  drone show when it starts or ends. As shipped, SB plays `P_Eve_Gun_E` (in a fight) or `P_Eve_Gun_E_Peaceful` on her
  whole body when the aim stance ends: the drone aim's side-on exit with bent knees. When the aim starts it plays
  `P_Eve_Gun_S` or `P_Eve_Gun_S_Peaceful`: the drone's side-on raise, 1.1 s long. The shipped exit took over from the
  raise at the release. With only the exit emptied the raise played to its end, so a short aim left her standing
  side-on with the rifle at the hip for up to 1 s. While the rifle is out, all four paths are empty. `UE4SS.log` has
  the lines `data: aim stance StartShowPathWhenPeaceful cleared`, `data: aim stance StartShowPathWhenBattle cleared`,
  `data: aim stance EndShowPathWhenPeaceful cleared` and `data: aim stance EndShowPathWhenBattle cleared`.
- `CharacterAnimSetTable`: not on the rifle layer. With the rifle clips alone, the aim stance's animation set points at
  the rifle's blend spaces. A spare NPC row takes EVE's peaceful set with the rifle clips for the carry. The test line
  `gun_bs` changes the aim stance's blend spaces too.
- The NIKKE shot's show `P_Eve_GunNikke_ShootSlug1` (with `gun_fire=native`): its animation key plays no animation.
  As shipped it plays `P_Eve_GunNikke_Shoot` on her whole body, the NIKKE missions' shot from behind cover, which bent
  her body down at each round. The round, its sound, its flash and the camera shake play as before. The test line
  `gun_upper=nikke` keeps the animation, as does `gun_fire=own`. A show the engine collected while the rifle was out is
  not written to. `UE4SS.log` has the line `SBShowAnimKey_1 AnimResourcePath emptied`.

## Keys

| Key | Pad | What it does |
| --- | --- | --- |
| G (`gun_key`) | A tap of D-pad Right | Rifle out or away. A hold of D-pad Right is the bike's |
| RMB (held) | LT (held) | Firing mode: the camera comes over her shoulder, the laser sight and the reticle come up |
| LMB | RT | In firing mode: full auto. Without RMB / LT: hip fire ([Firing mode](#firing-mode)) |
| Space | A | In firing mode: jump, still firing |
| B | Triangle | Reload: the magazine is topped up from the spares |

With the rifle out and no button held, EVE moves as usual with the rifle at low ready (luke77's rifle carry on the
posed stance). The sword's attacks are off until the rifle is put away. Their keys come back while the game is paused,
so the game's key options never save them off. The first frame after the pause masks them again. When the keys go
back, gun mode finds each mapping again by its action name: coop fly may have moved the mappings in memory meanwhile.

A new map, a death or a camp warp puts the rifle away. The hidden drone shows again, her facing goes back and the
arrival's cube goes, once the new EVE is there. A drone part whose path no longer names it is left alone: after a
map load another object can sit at its address. The next rifle out starts clean on her.

While the game holds EVE in an interaction or a cutscene (a camp, a seat, a rest, a door, a level sequence), the
rifle goes away. It comes back 1 s after she is free. A press of `gun_key` in that second cancels the comeback. So do
a press whose departure the interaction cut short and a new map. A comeback the game refuses (the drone aim held, a
cutscene again) is tried again 2, 4 and 8 s later, then given up with a `no comeback` line. A comeback that fails
with an error gives back what it took and logs `off: the comeback failed (...)`. `UE4SS.log` names the reason on a
`[GM]` line. The rifle does not come out with no EVE in the game world, while the drone aim is held, in a cutscene or
in an interaction: a press then gives a `not now:` line. The game's hold of her movement, a jump, a swim and SB's
other movement modes keep it allowed. Gun mode checks no other state: the rifle can come out on the bike, in a Doro
race, on a hall seat, in flight, in the photo and selfie modes or during an SBO match. The bike does not mount while
the rifle is out. SBO's PvP rule counts a hit only from 15 m or closer, whatever the move. The rifle's rounds reach 100 m: a hit from farther than 15 m costs the other player
nothing.

`coop off` puts the rifle away at once, with no departure, also right after a press or while a new map's reset still
waits. The table fields, the keys and her body's own post-process class go back. The HUD entry and the crosshair come
off SB's HUD. Gun mode then does nothing until the game restarts: no key, no `coop gun`, no reset. A rifle out that
fails part way (the rows, the keys or the rifle) gives back everything it took and logs an `off:` line. Gun mode keeps
no file of what it changed: a Lua reload (Ctrl+R) with the rifle out leaves its table fields, keys and layer in memory
until the game restarts. The next load takes the earlier load's HUD entry and crosshair again.

## Firing mode

Firing mode is the game's own drone aim (`gun_fire=native`, the default) with a few changes. On the rifle layer her
arms take the aim pose with the rifle on the camera's line. On the posed stance her upper body takes luke77's rifle aim
on her normal standing spine. The camera's field of view is 66 (the game's aim uses 45), so her hips and the rifle stay
in frame. She runs, strafes and backpedals at the aim stance's speed times 1.4.

Every round is the NIKKE shot, whatever drone round is selected. It spends no drone ammo. Each round flies from the
muzzle to the point under the reticle. Gun mode writes that point ten times a second in firing mode and before each
round it fires itself. Each write moves the point at random within `gun_spread` degrees, seen from the camera: 0.5
unless set, 0 for none. Rounds that leave between two writes share one point. The `[GM]`
lines `round #N` and `shot #N` number the rounds of a rifle out in one count, the game's and gun mode's own. The first
three and one in fifty get a line. `round #N` is a round of the game's aim. It gives where SB sends that round against
the reticle point. That place is the destination SB computes from her root when the round spawns, read back from the
row. It is not a measured impact. When the row does not place the destination in her root frame, the line names its
`DestTarget`, transform and axis instead. `shot #N` is a round gun mode fired itself (hip fire, a jump). It gives the
camera, the target and EVE's place.

A reload in firing mode keeps her aimed. Only her arms and hands move: the rifle tilts and her left hand goes to the
magazine.

When the rifle goes away while the game's aim is still on (G in firing mode, a cutscene), the aim stays on RMB and
the trigger fires nothing until the aim ends: the NIKKE shot's cool time reads 999. The game's aim drops for a frame on
each shot while RMB / LT is held. An off on such a frame counts as an off in the aim. Letting RMB / LT go ends it. The
keys and SB's rows then go back with the line `drone aim hold over`. A rifle out, a new map and `coop off` end it too.

A jump drops the game's aim stance in the air. Gun mode keeps the rifle up, keeps her turned to the camera and fires
the NIKKE shot itself from the jump's second frame until the aim button is let go, after landing as well. Press RMB / LT
again to get the game's
strafing aim back. On the rifle layer each of these shots waits until the rifle points within 10 degrees of the
reticle point. Without the layer nothing measures the rifle's line, so the shots leave at once.

LMB / RT without the aim button is hip fire. On the rifle layer the rifle comes up in the aim pose. EVE turns to the
camera through her own movement. Gun mode fires the NIKKE shot itself once the rifle points within 10 degrees of the
reticle point. Without the layer hip fire fires nothing.

In firing mode the laser sight runs from the rifle's muzzle to the reticle point. It comes on 0.12 s after the aim
starts once the barrel points within 25 degrees of that point. When the barrel is further off it comes on 0.6 s after
the aim starts. With the rifle clips alone the rifle turns in her hands onto that line when it is 6 degrees off or
less. On the rifle layer her upper body turns to the aim and the rifle is not turned. The beam hangs from the muzzle socket through a component of its own, so a
partner's game never copies it. The laser shows on your screen only: its end is a value each game keeps for its own
world, so a copy on another player's screen would point elsewhere. During the double-jump flip the laser and the
rounds both run along the rifle's bore.

On the posed stance, the posed body and the rifle you see are drawn for your own camera only.

## Rounds

The rifle fires NIKKE RAPID rounds: about 20 a second.

| | |
| --- | --- |
| Magazine | 60 rounds |
| Reload | 1.6 s, with the NIKKE squad's reload sounds |

The magazine reloads when it runs dry or when you press the reload key (B, or Triangle on a pad). A press throws away
the rounds left in the magazine and loads a new one from the spares. With fewer spares than a magazine, every spare
goes in.
Lowering the rifle never reloads it. No round fires while it reloads. With `gun_fire=own` gun mode's own shots use
the same magazine and reloads.

The `[GM]` line `off (...), N shots` counts the rounds of the rifle out, the game's aim's included. For a shot sound
that goes missing, two `[GM]` lines list EVE's audio components and the ones playing. `sounds while firing:` comes once
a rifle out, after 30 rounds. `sounds at the off:` comes each time the rifle goes away. A pooled sound has another
owner, so neither line counts it.

In firing mode the reticle's round slot shows the round's name and the rounds left in the magazine. The game writes
its own round's name when its aim starts, so gun mode writes the slot on each frame of the aim's first 0.25 s. While
the rifle reloads the name reads RELOADING. With the magazine and every spare empty it reads NO AMMO. The three words
are English, from `fight/gunmode/config.lua`. The slot's text blocks are kept with their paths: after a map change gun
mode writes nothing to another object that took a freed block's address.

A gun mode entry sits in SB's HUD to the right of the D-pad marker, below the SH bar. It shows the button that brings
the rifle out: on a pad the D-pad Right glyph of the pad the game shows, on the keyboard the `gun_key` icon on the
game's own key cell. That cell is the D-pad marker's `btn` image, found by name in the marker's widget tree. Without it
the icon shows alone. The log says `dpad: rifle entry built, key cell found` or `key cell not found`. Then comes the
NIKKE rifle icon. While the rifle is out it also reads `rounds | magazines`: the rounds in the magazine, then the
magazines left (a part-spent one counted). The icon is the game's NIKKE rifle texture,
`Icon_Nikke_LostItem_AssaultRifle`, the icon of the item table's `Nikke_AR` row. Gun mode loads it from the game. While
the native part runs, SBO's keep holds it across map changes. No image file ships with SBO. The entry is a child of the
HUD's own D-pad marker, so it shows and hides with the HUD. A new HUD (after a map change) gets the entry built again
with its key, cell, sizes and place. A box the marker's size holds it, so the item column never grows. Gun mode keeps
the entry's widgets with their paths and uses them only while those paths still name them. After a Lua reload the new
load takes the earlier load's entry and crosshair again instead of making new widgets over them, which would destroy the
live ones in place. The entry's parts are found by their names in the HUD's widget trees. A HUD without the D-pad marker
is tried once. While the native part runs, the keep also holds SB's HUD class (`WB_MainHUD_Master_C`). A hook on its
Construct, registered in `fight/gunmode/wiring.lua` once a Lua load, then names each new HUD. The entry is built within
a tenth of a second of that HUD coming on screen, with no walk of the game's objects. The log line then ends with
`(HUD from its Construct)`. Gun mode waits 4 s after a new map, a death or a camp warp: a HUD shown sooner gets the
entry when that wait ends. Without the hook (a Lua reload before the next map, the keep off, a hook that failed) gun
mode looks for the HUD on screen: once 2 s after the entry was built, then every 10 s while it finds none it can use. In
hip fire (the rifle up without the game's aim) a small crosshair shows at the screen's centre, on the HUD the entry was
built in. `hud_entry=false` in `fight/gunmode/config.lua` turns the entry off.

### Free magazines

The rifle has free magazines: 5 spare magazines of 60 rounds. A new map, a death or a camp warp gives full magazines
again. Putting the rifle away and taking it out again does not. Gun mode starts no round store: `fight/gunmode/wiring.lua`
starts neither `fight/gunmode/nikke.lua` nor the rows below, so no `Bullet_Nikke` is sold, dropped or spent.

## The rounds' rows

Not started in this version (see Free magazines above). The files stay as they are.

The batch `nikke` (`native/src/fight/gunmode/nikke_rows.h`) leaves `Bullet_Nikke` (ItemTable ID 37) as it ships. It
adds 9 rows and patches 3 shipped rows in place, in this order:

| Table | Row | ID | Copied from | What changes |
| --- | --- | --- | --- | --- |
| RewardGroupTable | `31114` to `31121` | 31114 to 31121 | each group's own row (`200026`, `200030`, `200016`, `200020`, `200035`, `220025`, `200024`, `31105`) | `ItemAlias` `Bullet_Nikke`, `DropRate`, `ItemMinCount`, `ItemMaxCount`; the group is the donor's |
| ShopItemTable | `SBO_Camp_Bullet_Nikke_Buy` | 37001 | `Camp_Bullet_Normal_Buy` | `ItemAlias`; `MoneyItemCount1` and `FriendShip` 2; `CheckConditionGroup` None |
| ShopTable | `Shop_SimpleCamp` | 1001 | itself | `ShopItems`: the shipped list with `SBO_Camp_Bullet_Nikke_Buy` after `Camp_Bullet_Railgun_Buy` |
| ShopTable | `Shop_FullCamp` | 1002 | itself | the same |
| ShopTable | `Shop_NestCamp` | 1003 | itself | the same, with its own first item (`Camp_ResurrectionItem_Buy`) |

The donor shop item's condition `CG_TPSMode_Opened` is the drone's gun: the copy clears it. RewardGroupTable is the
row engine's 40th table, written by this batch only. Every one of the eight groups is RandomEach. SB adds a row naming
an `ItemAlias` with `rand(ItemMinCount, ItemMaxCount)` rounds (`FUN_141bea040`). The row offsets and the functions are
in the header's comments, read in Ghidra on build 26123051.

`fight/gunmode/nikke.lua` asks the batch through `core/enemy.lua`'s rows flow from the 250 ms loop, once the slot line
reads `slot=coop` with `saves=coop`: a co-op save from the co-op save files is loaded. The native part then refuses
`coop saves main` until the game restarts (`game/twins.h`). The batch goes in on the game thread through the row
engine's gate (net mode 0, no logic task in flight), as `coop lion` adds its rows in a loaded world. Its three shop
rows are patched in place with `CopyScriptStruct`. In Ghidra the shop row's readers through the ID lookup
(`FUN_141bd6d00`, table 0x54), the buy (`FUN_141bbe480`) and `FUN_141bbf810`, walk `ShopItems` within one call, so no
reader holds the old list across the write. Then it reads every row back through FindRow against
`fight/gunmode/rows.lua`. A refusal for a shut gate (busy, net, unread) is asked again 10 s later, at most 4 times a
load of a co-op save. A refusal for another reason, a fault or a row read back other than written keep the free
magazines for the game run. With `gun_mode=off` the object is not made: gun mode asks no rows.

The object is ready while the rows are in and the last `slot=coop` or `slot=main` line said `slot=coop`. An unread
status, `slot=none` (a load, the title) and `slot=unknown` change nothing.
While it is ready, `fight/gunmode/ammo.lua` takes its spares from it. When it stops being ready, the magazine goes back
to free magazines (`mag_size` in the magazine, `spare_mags` spares).

- The count: the native part's `items` request (`items <ask> Bullet_Nikke <index> <number>`, answered in the engine
  line's `items=`), once a second while the rifle is out. Gun mode's ask numbers run from 20000 to 32767. `coop gift`'s
  start at 1. The bike's paid fetch's start at 32768. An answer for another number is left to its owner. Rounds taken
  that no read shows yet count as gone until a read shows them, 10 s of play at most (paused time not counted). A take
  that no read shows in that time is logged. On your own save or another co-op save the count is dropped and read
  again. `coop-link.log` and `UE4SS.log` get a read's line only when the count changes.
- The take: SB's own `ServerRequest_ItemBucketItemRemove` (bucket 1, EVE's GUID, `Bullet_Nikke`, the count, no
  pocket), once a reload, for the rounds the magazine loads. That is at most `mag_size` and at most the count she
  carries then (the last read less the takes it does not show yet). A take is refused while SB's logic is paused, with
  no EVE or no GUID for her. A refused take loads nothing. The next empty reload then waits 5 s (`Ammo.RETRY`). The
  take uses gun mode's own controller and EVE. Looking them up again walked the game's objects twice: each reload
  froze a frame for 64 to 66 ms in the 2026-11-21 test.

Gun mode calls no item add, save, shop or drop function. SB's own buy and drops add the rounds. `UE4SS.log` has the
`[GM]` lines `ammo: the magazine loads from the round store (Bullet_Nikke)` once the rows are in, `ammo: out of rounds`
(once, until rounds come), `ammo: N rounds not taken (<why>): nothing loaded`,
`ammo: free magazines (the round store is not ready)`, `rounds: a co-op save loaded: the rows asked (try N of 4)` and
`rounds: N taken but the count did not fall in 10 s`.

## Frame cost

With `gun_mode=on`, gun mode asks SBO's keep for the assets of the rifle out, the aim, the rounds and the reload when
it loads: the rifle layer's class and its four poses, the camera modifier, the rifle mesh, the morph's cube and flash,
the muzzle flash, the three reload sounds, the two turn clips, the laser sight's Niagara system and parameter
collection (`NS_A_GuideLaser`, `NC_NikkeMinigame`), the NIKKE shot's show `P_Eve_GunNikke_ShootSlug1` and the two
bodies the layer's rebuild swaps in for a moment (`Overlay.BASES` in `fight/gunmode/overlay.lua`). While the native
part runs, the keep loads them off the frame and holds them for the game run. Any other asset, or one the keep does
not hold, is found in memory through the engine's name hash before it is loaded. UE4SS's own lookup walks the game's
objects for each asset not in memory: the first rifle out on a map froze the game for 100 to 340 ms in the 2026-11-21
test. The assets gun mode uses again (the reload sounds, the cube, the morph's flash, the muzzle flash, the turn clips,
the laser's five objects) are kept between uses. Each is checked by its path before it is used, since a collection can
free it.

The second body of `Overlay.BASES` is `CH_P_EVE_01/CH_P_EVE_01`, which no pak of build 26123051 holds. With EVE in
`CH_P_EVE_29` the layer finds no other body and the rifle comes out without it, as before. That missing body, like a
pose the pak lacks, is looked for once a Lua load.

Gun mode walks the game's objects at these times only:

- the player controller, once a second while there is none (a title screen, a load);
- the HUD on screen, as the HUD entry above says;
- the pad's `Gamepad_DPad_Up` glyph, once each time the pad layer comes up until one is found, kept for that HUD;
- the reticle's round slot, at the rifle out and after firing mode, at most once in 10 s while it is missing. Never
  in firing mode: a walk at its start would land where she watches her body turn to the front;
- the drone, only when the engine's list of actors of its class (`CH_Drone_BP_C`, found by its path) cannot be read.
  The drone of the last rifle out is used again while it is within 30 m of her. With no drone that close gun mode
  looks again every 5 s.

The camera modifier is tried once a rifle out. The names `FX_Fire` (the muzzle flash) and `DefaultSlot` (the layer's
clips) are made once.

While the rifle is out, `UE4SS.log` has a `[GM]` line every 10 s: `perf: tick <average> ms average, <worst> ms worst,
<n> ticks, Lua <heap> KB; ms a tick:` and the six costliest parts of the tick.

## coop gun

| Command | What it does |
| --- | --- |
| `coop gun` | Rifle out or away, as `gun_key` does |
| `coop gun status` | On or off, firing mode or not, the key, the rounds fired |

## Settings

Gun mode reads its own lines of `coop-settings.txt` when the mod loads (game start or Ctrl+R).

| Line | Values | Default |
| --- | --- | --- |
| `gun_mode` | `on`, `off` (no key, no hook, nothing) | `on` |
| `gun_key` | One letter A to Z, or F1 to F12 but F10 | `G` |

Stellar Blade's input settings bind G to a menu action (`UI_RightThumbstick`). SBO's own settings still list
`gun_key` with F4: a `coop-settings.txt` that SBO writes new has the line `gun_key=F4`. Gun mode then uses F4. The
co-op menu's row for `gun_key` takes F-keys only.

The lines below are test lines. A new file does not have them and Options has no row for them. A line with an empty
value counts as absent. Gun mode checks five of them: `gun_aim_key`, `gun_zoom`, `gun_fire`, `gun_upper` and
`gun_spread`. A value
it refuses there keeps the default. `UE4SS.log` names it on a `[GM]` line, such as
`coop-settings.txt: gun_zoom: use hold or toggle`. The other lines get no log line. The last column says what a
value outside the list does.

| Line | Values | Default | Any other value |
| --- | --- | --- | --- |
| `gun_aim_key` | The UE key name firing mode moves to, letters and digits only (no `_`) | `RightMouseButton` | Refused and logged |
| `gun_zoom` | `hold`, `toggle`, in any case | `hold` | Refused and logged |
| `gun_fire` | `native` (the game's aim), `own`, in any case | `native` | Refused and logged |
| `gun_upper` | `nikke` (the NIKKE rifle's upper-body animations in firing mode), `off`, in any case | `off` | Refused and logged |
| `gun_spread` | Degrees from 0 to 10: how far a round may land off the reticle point, seen from the camera. 0: none | `0.5` | Refused and logged |
| `gun_probe`, `gun_trace` | `on` in any case: development logging | off | Read as off |
| `gun_facts`, `gun_g0` | `on` in lower case: development probes (`fight/gunmode/facts.lua`, `fight/gunmode/g0.lua`) | off | Ignored |
| `gun_bs` | A blend space for the aim stance's animation set | none | Not checked: taken as written |
| `gun_carry_ovr` | `auto`, `off` (her own walk) or an animation set row, as letters, digits and `_` | `auto` with the rifle clips alone | A word other than `auto` or `off` in lower case is taken as a row name. Other characters: ignored |
| `gun_carry_spare` | Which spare animation set row the rifle carry takes, from 0 | 0 | Not a number: ignored |
| `gun_carry_idle` | The rifle carry's idle type, a number | 1 | Not a number: ignored |
| `gun_fire_key` | One more fire key, a UE key name in letters and digits only (no `_`) | none | Ignored |

## Credits

- The rifle stance (`fight/gunmode/stance.lua`) and the laser sight (`fight/gunmode/laser.lua`) started as luke77's
  RifleStance, which Lucas (luke77) contributed to this project in the commit "feat: add standing rifle stance and
  aiming laser".
- Gun mode around them is by SchizoEffective.
- The NIKKE rifle, its shot, its animations and its sounds are the game's own and belong to SHIFT UP.
