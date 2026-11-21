# Gun mode

Gun mode gives EVE the NIKKE DLC's rifle outside its missions, on any save, as a third-person shooter. It is
experimental: it has been played on one PC only, not yet between two players.

## Parked while it is rebuilt

`gun_key` (F4) or a tap of D-pad Right shows the notice "Gun mode: rebuilding" and does nothing else: no table field
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
- `SkillTable`: the NIKKE shot's cool time (the rate of fire).
- `SkillActiveStepTable`: the shot's `Hit1` step takes the `Type` of its `Cast1` step. It fires its projectile and
  spends no round.
- `ProjectileTable`: the round leaves the rifle's muzzle for the crosshair point. Its destination is an offset from
  EVE's root in her root's frame (`DestTarget` MainActor). The shipped `StartToDestDirection` aimed along SB's own
  target line and sent the rounds to the side. Its own spread (a random range of 300 cm) is off. Its destination is
  placed once, when the round spawns, not again while it flies.
- `CharacterStanceTable` (with `gun_fire=native`): the aim stance is faster. A jump does not end it.
- `CharacterAnimSetTable`: not on the rifle layer. With the rifle clips alone, the aim stance's animation set points at
  the rifle's blend spaces. A spare NPC row takes EVE's peaceful set with the rifle clips for the carry. The test line
  `gun_bs` changes the aim stance's blend spaces too.
- The NIKKE shot's show `P_Eve_GunNikke_ShootSlug1` (with `gun_fire=native`): its animation key plays no animation.
  As shipped it plays `P_Eve_GunNikke_Shoot` on her whole body, the NIKKE missions' shot from behind cover, which bent
  her body down at each round. The round, its sound, its flash and the camera shake play as before. The test line
  `gun_upper=nikke` keeps the animation. `UE4SS.log` has the line `SBShowAnimKey_1 AnimResourcePath emptied`.

## Keys

| Key | Pad | What it does |
| --- | --- | --- |
| F4 (`gun_key`) | A tap of D-pad Right | Rifle out or away. A hold of D-pad Right is the bike's |
| RMB (held) | LT (held) | Firing mode: the camera comes over her shoulder, the laser sight and the reticle come up |
| LMB | RT | In firing mode: full auto. Without RMB / LT: hip fire ([Firing mode](#firing-mode)) |
| Space | A | In firing mode: jump, still firing |
| B | Triangle | Reload: the magazine is topped up from the spares |

While the rifle arrives in her hand (0.45 s after F4 or the D-pad tap) RMB and LT do nothing. A press after that
starts firing mode. With the rifle out and no button held, EVE moves as usual with the rifle at low ready (luke77's
rifle carry on the posed stance). The sword's attacks are off until the rifle is put away. Their keys come back while
the game is paused, so the game's key options never save them off. A new map, a death or a camp warp puts the rifle away.

The rifle does not come out during a cutscene, a talk or another interaction, while the game holds her movement, in the
photo and selfie modes, or while her movement mode is other than walking or falling (swimming, flying, a custom movement
mode or none). If one of these starts with the rifle out, the rifle goes away within a quarter of a second. The same
holds while EVE rides the bike, wears the Doro look, plays a `coop emote`, sits on a hall seat or uses `coop fly` or
`coop glide`. The hold of her movement is the exception once the rifle is out: the game can raise it during its own
drone aim, which is firing mode. The rifle then stays out. `UE4SS.log` names the game's actions and axes on the keys
held at that moment, with `[AZERTY]` after a mapping of the AZERTY keyboard layout. The bike does not mount while the rifle is out. `UE4SS.log` names the reason on a `[GM]` line. A key press
or D-pad tap that the rifle refuses also shows a notice on screen: release the drone aim, EVE is not in the game world,
EVE cannot take the rifle now, or the start failed.

After a cutscene, a talk or another interaction that put the rifle away, the rifle comes back 1 s after EVE is free,
once the game is not paused. A press of the gun mode key cancels this, also during the 0.4 s the rifle takes to go
away. A new map, the bike or another module's hold on EVE cancels it too. A comeback that the rifle refuses (the drone
aim held, for example) is tried again 2, 4 and 8 s later. After the fourth refusal the rifle stays away and
`UE4SS.log` has the line `no comeback: refused 4 times`.

During an SBO match (a round in play, or the PvP test of `coop pvp`) the rifle stays away too, with a notice. SBO's
PvP rule counts a hit only from 15 m or closer, whatever the move. The rifle's rounds reach 100 m: a hit from farther
than 15 m would cost the other player nothing.

`coop off` puts the rifle away too. The table fields, the keys and her body's own post-process class go back. Gun
mode then does nothing until the game restarts. Until everything is back, `coop-gun.txt` lists what gun mode changed.
A frame writes it once at its end. The frame of a rifle out writes it twice at most: the start checks its own write.
After a Lua reload (Ctrl+R) the next load puts those changes back at its first frame. It shows her hidden meshes to
her camera again. Each drone part gets the visibility it had before the rifle came out, so a part the game kept
invisible stays invisible. It turns off the carry stance and removes the rifle, the morph's cube or the posed copy it
finds on her. Her mesh gets the rotation it had before the game's aim turned it. The aim camera's modifier comes off
the camera manager, so the next rifle out adds one modifier, not a second. Her movement gets its own facing flags back.
It takes the HUD entry and the crosshair off SB's HUD, with gun mode on or off.

## Firing mode

Firing mode is the game's own drone aim (`gun_fire=native`, the default) with a few changes. On the rifle layer her
arms take the aim pose with the rifle on the camera's line. On the posed stance her upper body takes luke77's rifle aim
on her normal standing spine. The camera's field of view is 66 (the game's aim uses 45), so her hips and the rifle stay
in frame. She runs, strafes and backpedals at the aim stance's speed times 1.4.

Every round is the NIKKE shot, whatever drone round is selected. It spends no drone ammo. Each round flies from the
muzzle to the point under the reticle in the frame it leaves. Gun mode writes that point every frame of firing mode.
Rounds land at random within `gun_spread` degrees of it, seen from the camera: 0.5 unless set, 0 for none. The `[GM]`
lines `round #N` and `shot #N` number the rounds of a rifle out in one count, the game's and gun mode's own. The first
three and one in fifty get a line. `round #N` is a round of the game's aim. It gives where SB sends that round against
the reticle point. That place is the destination SB computes from her root when the round spawns, read back from the
row. It is not a measured impact. When the row does not place the destination in her root frame, the line names its
`DestTarget`, transform and axis instead. `shot #N` is a round gun mode fired itself (hip fire, a jump). It gives the
camera, the target and EVE's place.

A reload in firing mode keeps her aimed. Only her arms and hands move: the rifle tilts and her left hand goes to the
magazine.

When the rifle goes away while the game's aim is still on (F4 in firing mode, a cutscene), the aim stays on RMB and
the trigger fires nothing until the aim ends. The game's aim drops for a frame on each shot while RMB / LT is held. An
off on such a frame counts as an off in the aim. Letting RMB / LT go ends it. The keys and SB's rows then go back. Gun
mode fires no round of its own on such a frame: the game's aim fires its own. Her body keeps its turn toward the aim
through it.

A jump drops the game's aim stance in the air. Gun mode keeps the rifle up, keeps her turned to the camera and fires
the NIKKE shot itself from the jump's second frame until the aim button is let go, after landing as well. Press RMB / LT
again to get the game's
strafing aim back. On the rifle layer each of these shots waits until the rifle points within 10 degrees of the
reticle point. Without the layer nothing measures the rifle's line, so the shots leave at once.

LMB / RT without the aim button is hip fire. On the rifle layer the rifle comes up in the aim pose. EVE turns to the
camera through her own movement. Gun mode fires the NIKKE shot itself once the rifle points within 10 degrees of the
reticle point. Without the layer hip fire fires nothing.

In firing mode the laser sight runs from the rifle's muzzle to the reticle point. The rifle turns in her hands onto
that line every frame, up to 6 degrees. The beam hangs from the muzzle socket through a component of its own, so a
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

The magazine reloads when it runs dry or when you press the reload key (B, or Triangle on a pad). A press keeps the
rounds left in the magazine and tops it up from the spares. With fewer spares than it lacks, every spare goes in.
Lowering the rifle never reloads it. No round fires while it reloads. With `gun_fire=own` gun mode's own shots use
the same magazine and reloads.

The `[GM]` line `off (...), N shots` counts the rounds of the rifle out, the game's aim's included. For a shot sound
that goes missing, two `[GM]` lines list EVE's audio components and the ones playing. `sounds while firing:` comes once
a rifle out, after 30 rounds. `sounds at the off:` comes each time the rifle goes away. A pooled sound has another
owner, so neither line counts it.

In firing mode the reticle's round slot shows the round's name and the rounds left in the magazine. The game writes
its own round's name when its aim starts, so gun mode writes the slot on each frame of the aim's first 0.25 s. While
the rifle reloads the name reads RELOADING. With the magazine and every spare empty it reads NO AMMO. RELOADING and NO AMMO show
in the co-op menu's language; NIKKE RAPID stays as it is.

A gun mode entry sits in SB's HUD to the right of the D-pad marker, below the SH bar. It shows the button that brings
the rifle out: on a pad the D-pad Right glyph of the pad the game shows, on the keyboard the `gun_key` icon on the
game's own key cell. With `gun_key=none` the keyboard button stays empty. Then comes the NIKKE rifle icon. While the
rifle is out it also reads `rounds | magazines`: the rounds in the magazine, then the magazines left (a part-spent one
counted). The icon is the game's NIKKE rifle texture, `Icon_Nikke_LostItem_AssaultRifle`, the icon of the item table's
`Nikke_AR` row. Gun mode loads it from the game. While the native part runs, SBO's keep holds it across map changes. No
image file ships with SBO. The entry is a child of the HUD's own D-pad marker, so it shows and hides with the HUD. A
box the marker's size holds it, so the item column never grows. While the native part runs, the keep also holds SB's
HUD class (`WB_MainHUD_Master_C`). A hook on its Construct, registered in `fight/gunmode/wiring.lua` once a Lua load,
then names each new HUD. The entry shows within a tenth of a second of that HUD coming on screen, with no walk of the
game's objects. Gun mode waits 4 s after a new map, a death or a camp warp: a HUD shown sooner gets the entry when
that wait ends. Without the hook (a Lua reload before the next map, the keep off, a hook that failed) gun mode looks
for the HUD on screen once every 10 s. That look walks the game's objects. The entry's parts are found by their names
in the HUD. A new HUD (a map change, a death, a camp warp) gets the entry built anew. A HUD without the D-pad marker
is tried once. After a Lua reload the new load takes the earlier load's entry again instead of building a second one
over it. A name UE4SS does not find costs a walk of the game's objects too, so gun mode looks for its own widgets by
name only once an earlier load's row is in the marker. Each build looks for that row once. In hip fire (the rifle up
without the game's aim) a small crosshair shows at the screen's centre. Its first build in a HUD looks once for an
earlier load's crosshair. `hud_entry=false` in `fight/gunmode/config.lua` turns the entry off.

The rounds below have not run in game yet. The rest of this section is written from the code and the game's tables.

### Rounds on a co-op save

On a [co-op save](../players/saves.md#co-op-saves) the rifle's rounds are an item EVE carries: `Bullet_Nikke`, the
game's own round of the NIKKE stage. The mod adds no item. It adds where to get the round:

- The camp vending machines sell it for 2 gold a round, at simple camps, full camps and nest camps. It is listed after
  the drone's railgun rounds. The machines' item that refills all ammo refills the rounds of EVE's bullet slot list
  (the player data's list that `FUN_141cc63d0` copies), each up to its carry limit (`FUN_141bbe480`). The mod never
  puts `Bullet_Nikke` in that list. Whether anything in the game does was not read.
- Enemies and supply boxes drop it, beside the drone's ammo. Each row below rolls on its own: its chance out of 100,
  then a count between its two numbers. The enemy counts come from the game's table dumps.
- EVE carries at most 60 rounds, 62 with the drone upgrade `P_Protector_Shoot2_5` (below). That is one spare magazine
  beside a full one. A drop or a buy past that limit adds only what fits.

| Drop group | Who rolls it | Chance | Rounds |
| --- | --- | --- | --- |
| `subGroup_FA_Normal_Bullet` | 18 kinds of enemy | 15% | 15 to 30 |
| `subGroup_FA_Normal3_Bullet` | 9 kinds of enemy | 20% | 20 to 40 |
| `subGroup_global_Normal_Bullet` | 8 kinds of enemy | 10% | 10 to 20 |
| `subGroup_global_Normal3_Bullet` | 2 kinds of enemy | 15% | 15 to 30 |
| `subGroup_FA_BodyBag_Bullet` | 2 kinds of enemy | 30% | 30 to 60 |
| `subGroup_Raven_Bullet` | 2 kinds of enemy | 30% | 30 to 60 |
| `subGroup_FA_Animal_Bullet` | 13 kinds of enemy | 10% | 10 to 20 |
| `subGroup_b_standard_Bullet_Random` | Supply boxes | 50% | 20 to 40 |

The shop and drop rows go in once a co-op save from the co-op save files has loaded, once a game run. The title, your
own saves and the manual co-op slot that `StellarCoopSlot.txt` names never ask them. From that load on the game refuses
`coop saves main` until it restarts, so none of your own saves loads while the rows are in. The rows stay for the rest
of the game run. The magazine loads from the inventory only while a co-op save is loaded. Then the
magazine starts empty. Each reload takes the rounds it loads out of EVE's inventory in one take, at most a magazine
and at most what she carries. The rounds she carries are the spares. An empty magazine reloads as
soon as she carries rounds (a buy, a drop). With none in the magazine and none carried the reticle's slot reads NO AMMO.

Rounds in the magazine have already left the inventory. They stay in the magazine across a new map, a death or a camp
warp. Nothing gives them back to the inventory: not putting the rifle away, not `coop off`. A reload loads nothing
when the game cannot take the rounds, for example while the game is paused. An empty magazine then reloads again
after 5 s.

Each player buys and picks up rounds in their own game. Nothing of the rounds goes over the Steam link.

### Free magazines

On your own saves the rifle keeps its free magazines: 5 spare magazines of 60 rounds. A new map, a death or a camp
warp gives full magazines again. Putting the rifle away and taking it out again does not. The same holds on a co-op
save without the Steam link or the native part, or when the rows were refused or read back other than written.
`UE4SS.log` then has the `[GM]` line
`rounds: rows refused (...): the rifle keeps its own magazines` or
`rounds: rows read back other than written: the rifle keeps its own magazines`.

### Not known or not checked

- The round's name may show empty in the machines and the inventory. `Bullet_Nikke`'s name and description fields are
  empty in ItemTable. No `Item_Bullet_Nikke_` key ships in ItemStringTable. How the game shows an empty name was not
  read.
- Its icon is the drone's normal round's (`bullet_icon_01`).
- Like every shipped round, its row has SaveType None. Whether the rounds EVE carries survive a save and a reload was
  not tested.
- Its carry limit is an actor stat no other item uses. SB's bucket add (`FUN_141bdbc20`) cuts an add down to the
  room left under the item's cap (`FUN_141be1440`): ItemTable `MaxAmount` (+0x84), or, in the player's bucket, the
  owner's value of the stat that `MaxAmountOverrideActorStat` (+0x88) names. For `Bullet_Nikke` that is
  `ActorStatType_ItemStackBullet5`. EVE's `Player` CharacterTable rows set it to 60. Of EffectTable's rows only
  `P_Protector_Shoot2_5` (+2) and `P_Protector_Shoot2_MK2_5` (+0) change it. The cut applies only when the bucket's
  byte at +0x38 is set. That byte is the bucket's `bPlayerOwned` (`FUN_141ad8cd0`). SB makes the inventory bucket of the
  actor a controller takes (`FUN_141ba6820`) and of an actor spawned with an inventory (`FUN_141ad24d0`,
  `FUN_141ba7f60`) with it set. The buckets the save load makes (`FUN_141ad2fa0`) have owner 0 with it clear. That no
  bucket of EVE's comes from that load was not read.
- The camp machines carry the `AllShop` tag. A buy of rounds there counts toward the gold-spending trophy, as a buy of
  drone ammo does.
- A RandomEach group rolls each of its rows on its own (`FUN_141be9540`): a pick up to the constant
  `RewardRandomEachMax` (10000 by default) drops the row when it is at or below its DropRate.

## The rounds' rows

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
`[GM]` lines `ammo: the magazine loads from EVE's inventory (Bullet_Nikke)` once the rows are in, `ammo: out of rounds`
(once, until rounds come), `ammo: N rounds not taken (<why>): nothing loaded`,
`ammo: free magazines (no co-op save, or the rounds' rows are not in)`, `rounds: a co-op save loaded: the rows asked
(try N of 4)` and `rounds: N taken but the count did not fall in 10 s`.

## Frame cost

With `gun_mode=on`, gun mode asks SBO's keep for the assets of the rifle out, the aim, the rounds and the reload when
it loads: the rifle layer's class and its four poses, the camera modifier, the rifle mesh, the morph's cube and flash,
the muzzle flash, the three reload sounds, the two turn clips, the laser sight's Niagara system and parameter
collection (`NS_A_GuideLaser`, `NC_NikkeMinigame`) and the two bodies the layer's rebuild swaps in for a moment
(`CH_P_EVE_29` and `CH_P_EVE_01_Body`). While the native part runs, the keep loads them off the frame and holds them
for the game run. Any other asset, or one the keep does not hold, is found in memory through the engine's name hash
before it is loaded. UE4SS's own lookup walked the game's objects for each asset not in memory: the first rifle out on
a map froze the game for 100 to 340 ms in the 2026-11-21 test. The layer's rebuild swaps in a body that is already in
memory when there is one. The keep holds both bodies so that none loads on the frame of a press: the layer's step took
49 ms at the first rifle out of that test and 11 ms at the next ones. Her drone comes from the engine's list of actors
of its class, `CH_Drone_BP_C`, found by its path. A walk of the game's objects found it at the first rifle out of that
test (36 ms).

While the rifle is out, `UE4SS.log` has a `[GM]` line every 10 s: `perf: tick <average> ms average, <worst> ms worst,
<n> ticks, Lua <heap> KB (lowest <low> KB), gun mode allocated at least <k> KB a tick; ms a tick:` and the six costliest
parts of the tick, then `; KB a tick:` and the six parts that allocate the most. The heap is the Lua heap of the whole
mod. Its lowest point over the 10 s goes up when something keeps memory. It also goes up when most of the garbage is
UE4SS's objects. UE4SS makes one at each read of a game object and at each call of a game function. Lua frees such
garbage one collection after it finds it, so each collection ends higher. In the second 2026-11-21 test the lowest point
went from 18 MB to 124 MB in 6 minutes, while the tests' fake game shows no table of gun mode growing. A carried frame
now reads 4 such objects and calls 16 game functions on that fake game (7 and 19 before). The heap went from 33 MB to
223 MB in 8 minutes with the rifle out in the first 2026-11-21 test. The `on` and `off` lines end with the heap at that
moment, so a rise while the rifle is away shows too.

## coop gun

| Command | What it does |
| --- | --- |
| `coop gun` | Rifle out or away, as `gun_key` does |
| `coop gun status` | On or off, firing mode or not, the key, the rounds fired |

## Settings

`gun_mode` and `gun_key` are SBO settings. A new `coop-settings.txt` has both lines. The co-op menu's Options page has
a row for each under Controls. Gun mode reads them when the mod loads (game start or Ctrl+R).

| Line | Values | Default |
| --- | --- | --- |
| `gun_mode` | `on`, `off` (no key, no hook, nothing) | `on` |
| `gun_key` | F1 to F12 but F10, with at most one of `Shift+`, `Ctrl+`, `Alt+`, or `none` | `F4` |

`gun_key` follows the rules of SBO's other keys. Options refuses a key that another SBO action holds. A file that gives
one key to two actions gets every key back at its default. A file written before `gun_key` whose own keys hold F4
gets no gun key. Stellar Blade's input settings bind no F-key. They bind G to a menu action (`UI_RightThumbstick`),
which is why G is no longer the default.

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
