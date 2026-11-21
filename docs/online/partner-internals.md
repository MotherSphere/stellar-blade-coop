# The ghost pipeline

The player's side is in [Ghost](partner.md).

The ghost goes through the same pipeline whatever its source: a linked friend, the loopback or a replay.

## 1. Capture

When the ghost is on, `online/partner/capture.lua` describes your EVE once she has been in the world for 2 s (never on a
menu pawn). It only reads. For each skeletal mesh part (up to 16, with up to 1024 bones each) it notes the mesh path,
the part it follows, the part and socket it hangs from, its placement there, whether it is shown, a leader's bone names,
and the map she is on (the package path of her world, lowercased). SBO's bike is one of those parts only while you ride
([The bike](../vehicles/bike-internals.md#ghosts)).

With the dyes look on, it adds each part's overridden materials, and for a dynamic material (one CNS made at run time)
the vector, scalar and texture values set on it, read from `VectorParameterValues`, `ScalarParameterValues` and
`TextureParameterValues`. A look reads one part's values and a new generation reads all of them, so 16 parts take 16 s
at worst to read a change. A change goes out again under the same generation, compared at 3 significant digits, at most
one such table each 5 s (21 s at worst in all). A part hung elsewhere, shown or hidden goes at once and carries the
values read so far. The table's geometry comes first: value lines stop at 56 KB and the `Capture ...` line says how many
were left out. A texture goes only if the viewer's rule could load it: under the game's own folders, or a path your own
CNS packs declare.

Under the same rule as the materials, it also reads which material slots each part hides at LOD 0
(`IsMaterialSectionShown`). CNS hides slots for an outfit's `HiddenMats` and `MaterialToggles`, so the capture reads the
result on the component and never reads CNS itself. A change waits like a value change. Shape keys are not read, since
the ghost cannot draw them (see [Looks](#looks)).

With the effects look on, it adds what the native part needs to read her effects. A part whose ponytail cloth has a
collision asset of its own (`OverrideClothPhysicsAsset`) names it.

With the drone look on, it adds her drone. The native part finds the drone once a second on the game thread while her
capture is live (`online/partner/drone_game.inc`). It asks Stellar Blade's own companion lookup: the drone's CharID
(`CharID_N_Drone`, `FUN_141aafe60(0x11)`), then that CharID's FSBActors (`FUN_141aae2f0`) and each one's character
through the character map. It asks only in game, outside loading and SB's logic thread, while both globals the lookup
reads (`0x147037400` and `0x1470373b0`) are set and the world's actor manager and character map exist. Of the
characters found, it keeps the one nearest her main mesh within 30 m. The worker writes `coop-drone.txt` (`drone
0x<actor>` or `drone none`) when that changes. `core/link.lua`'s `drone()` reads it. A fault in the lookup sets `drone
none` for the run with one `drone off: fault ...` line. The capture takes the
SBCharacter at that address whose class is `CH_Drone_BP_C` and adds its meshes after hers and the bike's. Its main mesh
is a free part, placed by the pose instead of a `place` line. Its other meshes hang from it. A `light` line names its
SpotLight for the native read. Another drone actor has other component addresses, so it starts a new generation. A
drone the capture cannot read is left out with one `Capture: drone not read: ...` line. Her own parts go on.

A mesh outside the game's own folders (`/Game/[DLC_<n>/]Art/Character/`) comes from a mod. Such a part gets a tag: the
`UniqueFitID` that your CNS packs give its path (from `coop-cns.txt`), else the first two folders of the path
(`OutfitMods/FooSuit`). It also names its overridden materials and hidden slots with the dyes look off,
since CNS sets them when it puts the outfit on. With `mod_names=off`, no path outside the game's folders goes: such a
mesh goes as `-`, with no tag, and such a material or collision asset is left out.

The native part refuses a table whose pose would pass 16 KiB (about 900 leader bones in all). Before it publishes, the
capture counts the pose as the native part does and leaves out the last leader parts, with their followers, until it
fits; its log line then ends with `<n> leaders left out, over the pose size`.

It reads her again once a second. A new mesh (her outfit) starts a new generation, as does getting on or off the bike. A
part hung elsewhere (the blade drawn or sheathed), shown or hidden is published again under the same generation. The log
gives a `Capture` line per generation.

## 2. The component table

The capture becomes the component table: one plain-ASCII grammar used for the capture file, the wire and the remote
table handed to Lua. In order:

```
SBT <protocol>                                    the wire form only
generation <1 to 2^53>
map /<package path, lowercased>
part <i> <lead|-> <parent|-> <socket|-> <shown 0|1> <bones> <name> <path|->
place <i> qx qy qz qw tx ty tz sx sy sz           parts after 0: placement relative to the parent
free <i>                                          in place of place: a leader hung from nothing (her drone), placed by
                                                  the pose's free block
material <i> <slot> <path>                        up to 16, slots 0 to 63 rising: an overridden material
value <i> <slot> v <name> r g b a                 up to 32 a slot and 512 a table, slots rising: a vector value of
value <i> <slot> s <name> x                       that slot's dynamic material, a scalar, or a texture (a space in a
value <i> <slot> t <name> <path>                  name goes as ~)
hide <i> <slot>...                                optional: 1 to 64 slots 0 to 63 rising, hidden at LOD 0
cloth <i> <path>                                  optional: the collision asset of the part's cloth
mod <i> <tag>                                     optional: on a mod's mesh, the outfit it comes from
names <i> <bone>...                               leaders only: one per bone
```

A value line that breaks its rules is left out and counted, and the table is still taken: a number that is not finite or
is past 100000, a name over 64 bytes, a texture path the path rule refuses, a slot with no kept material, a repeated
name, a slot lower than the one before, or a line past a cap. The log has one note a run (`<n> value lines ignored in a
component table (said once a run)`). A value line outside its place is an unknown line, which refuses the table as any
other does. Hide lines follow the same rule: a slot past 63, slots not rising or a second hide line is left out and
counted with the value lines. Value and hide lines do not count for the layout, so a change in them never builds a new
ghost.

The capture file also carries the memory addresses the native part reads from (`read`, `light`, `effects` and `effect`
lines); those never go on the wire. The `fx <k> <path>` lines after the last part do: each names the effect index `k`
(20 to 64) by the path of a Niagara system (see [Looks](#looks)). A leader part has bones of its own. A follower follows
a leader's bones (her ponytail, for example). Part 0 is her main mesh. A table is at most 64 KiB. The native parser
checks every line (the tests fuzz it).

## 3. The pose codec

While poses are wanted (the loopback, a recording or a linked friend), `coop_tick` reads and encodes EVE's pose on the
game thread at the send rate, and the worker sends it. A pose message holds:

- a header: `SBP`, the protocol, the table's generation, a sequence number, the sender's clock when the pose was read,
  and a hash of EVE's map;
- the main mesh's world transform: translation as three floats, rotation in 6 bytes, scale in three 16-bit integers;
- each leader's bones in local space, 18 bytes a bone: rotation as the smallest three of its unit quaternion (6 bytes),
  translation in 1/32 cm and scale in 1/4096 (16-bit integers each);
- for each free part (her drone), right after the world transform, a 25-byte block: its main mesh's transform relative
  to her main mesh in the world transform's 24 bytes, then a state byte. Bit 7 of the state is set when the part was
  read this pose. Bits 0 to 6 are its light's step: the SpotLight's intensity / 4, rounded, up to 127, 0 while the
  light is hidden or missing. A hidden block is 25 zero bytes. A drone that cannot be read shows hidden while her own
  pose goes on;
- six effect slots of 15 bytes each: an index (1 to 19 for the fixed list of effects, 20 to 64 for the table's `fx`
  lines), the part it hangs on, a serial for each new instance, and its rotation and translation relative to the part;
- four event slots of 19 bytes each (`game/events.h`, `put_event` in `game/codec.h`): what her game played, by kind
  (sound, Niagara, Cascade, decal, trail start or end), a serial for each new event in the slot, its asset key (1 to
  4096), the part it is attached to (none: placed relative to her main mesh), two value bytes (a sound's volume and
  pitch in 1/64 steps, an effect's scale in 1/32 steps), its translation in whole cm and its rotation. An empty slot is
  19 zero bytes. An event waits at most 100 ms for a free slot. It holds the slot for at least 2 poses and 50 ms plus
  one send interval, so a member on the lowest pose cap (20 a second) gets a pose that carries it. The ghost plays each
  slot's serial once, when its playback reaches the first pose that carried it; a playback that starts (a new table, a
  new member) plays none of the events standing in its first poses.

A pose is at most 16 KiB; in the outfits measured it is 4.8 to 5.1 KB with the event slots. A world position beyond
1e7 cm, or not finite, is refused.

Since protocol 9 most poses go as deltas. A keyframe is a full pose as above. A delta has the same header, the age of
its keyframe in microseconds, the world transform and free blocks, one bit for each bone rotation, translation, scale,
effect slot and event slot, then the bytes of those that changed since the keyframe. The sender sends a keyframe first,
then every 250 ms, and whenever a delta would not be smaller. The receiver rebuilds the full pose from the keyframe it
holds and decodes it like a keyframe. A delta whose keyframe was lost on the way is dropped and counted as keyless; the
ghost waits for the next keyframe, at most 250 ms later. In tests a delta was 26 % (idle) to 41 % (combat) of the full
pose.

A bone's rotation, translation or scale counts as changed only when it is more than a small tolerance away from the
keyframe, in the codec's own steps: 2 steps on each rotation component (0.035° at most), 1 step of translation (1/32 cm)
and 1 step of scale (1/4096). Until it moves further, the receiver keeps the keyframe's value, for 250 ms at most. This
drops the fields that only flip their last step from float noise, and needs no change on the receiving side. The test
build `build/host/online_partner_delta_gain_test` reads a `coop-record.bin` and prints the stream's keyframes, deltas
and KiB/s with and without the tolerance: `build/host/online_partner_delta_gain_test coop-record.bin`. A recording holds
the stream you sent. The tool reads only a recording of its own protocol (23): a recording from an older protocol fails
its check (`protocol`). Every build since protocol 14 has the tolerance, so its recording already holds the keyframe's
values for those fields and both lines show the same KiB/s, the stream's rate with the tolerance. With no file the tool
measures two synthetic recordings; they show how the tool works, not what a real outfit saves.

## 4. Playback clock and interpolation

The receiving side keeps the last 24 poses (400 ms at 60 a second) and draws the ghost a little in the past, so a late
pose still arrives before it is needed:

- The clock tracks the lowest one-way lag seen (which, between two PCs, includes the offset between their clocks). It
  drops to any lower lag at once and otherwise rises 1 ms a second, so it follows drift both ways. A lag that stays
  250 ms above it for 5 s (a clock step) moves it at once.
- Without jitter the ghost is drawn 1.5 send intervals behind the newest pose. With jitter it is drawn far enough back
  that a late pose is still ahead of it (the recent jitter peak, decaying, capped at 250 ms).
- The send interval is the median of the last 8 gaps between the publications of the poses received. A match lobby
  member whose deltas the sender skips for her cap gets every 2nd or 3rd pose, so her interval is 33 or 50 ms, the
  spacing of the poses she receives. One hole, such as the deltas dropped after a lost keyframe, does not move the
  median, so it does not push the ghost further back.
- Between two poses the pose is interpolated. Past the newest one it is extrapolated by at most half an interval.
  After 3 s without a pose the old ones are dropped, so the ghost never slides across the gap.

Poses that belong to no table, or to a table the ghost is not built on yet, are counted as foreign and not drawn.

## 5. The ghost, built from the table

When a remote table arrives, the native part checks it and hands it to Lua as `coop-remote.txt`.
`online/partner/puppet.lua` builds the ghost from it:

- The ghost is a plain actor with one PoseableMeshComponent per part and no collision (the
  [solid partner](#solid-partner) adds one capsule when it is on). It is not a Pawn, so lock-on, AI and saves leave it
  out.
- It is built one mesh a frame, which spreads the loading over several frames. Each part loads the mesh its path names.
  Loading only brings a cooked game asset into memory: nothing is worn or unlocked. Each part keeps the mesh's own
  materials (unless the dyes look is on), so the ghost wears the captured outfit.
- Two kinds of path pass the native path rule: the game's own (`/Game/Art/Character/...` and
  `/Game/DLC_<n>/Art/Character/...`, names of letters, digits and `_`) and a mod's (`/Game/<folders>/<asset>.<asset>`,
  names of letters, digits, `_` and `-`, 255 bytes at most). A path is always a package's own asset, so never a
  Blueprint class or a sub-object. The rule checks the text only. Before any lookup or load, `online/partner/puppet.lua`
  lets a mod's path through only when one of your own CNS packs declares that exact path (`coop-cns.txt`) or a mod you
  both have in one version holds it (`coop-shared-assets.txt`), so a friend's table cannot make your game load anything
  your installed outfits and mods do not name. Such a path is loaded as a mod's asset even when it lies in the game's
  folders, as replacer-style mods put new assets there. After a load, the asset must be of the expected class (a
  skeletal mesh, a material, a physics asset) or it is not used.
- A mod's asset that `LoadAsset` does not find (it looks in the cooked asset registry, where added assets usually are
  not) is loaded through `AssetRegistryHelpers:GetAsset` with an asset data holding only its path, which loads it by
  path. This is still one asset a frame. The build line lists each mod asset with how it came (`in memory`,
  `by LoadAsset`, `by GetAsset` or `missing`).
- Each part gets the render flags of every EVE part in the game's Blueprint: lighting channels 0 and 1, and custom
  depth with stencil 10, the game's value for the player.
- Parts hang as the table says (parent part, socket, placement), and followers follow their leader. Without the
  cloth look, the ponytail is rigid. The ghost always draws its highest detail level, so it never pops as it walks
  away.
- The ghost stays hidden until the first pose and after a second without one, so it never stands frozen. Your friend's
  Steam name (or `loopback`, `replay`) stands above it, turned to the camera at each pose. The tag's font has only the
  Latin-1 characters: any other shows as `?`, and a name that would lose more than half its characters shows the
  partner card's word for them instead (`Partner`, in your language when the font has its letters). A name tag that
  fails is left out and the ghost stays.
- The same generation with a part hung elsewhere, shown or hidden is applied to the ghost in place. A new generation is
  a new ghost. The `Ghost ... built` log line gives the parts, the meshes loaded and their time, those on the base suit
  (with how many of its bones follow) and those left out.

Lua then names what it built in `coop-display.txt`. Each frame, `coop_tick` writes the leaders' bones into the ghost
behind the engine's own CopyPose write gate, and writes the main mesh's world transform into a mailbox: a scene
component that nothing else moves. Right after the native tick, Lua places the ghost's root from the mailbox. A write
that the engine's gate refuses is logged once each time the native part takes a new ghost or a new capture generation
(`write refused: ...`).

## 6. Fallback: the base suit

A part falls back to the base suit when the path rule refuses its path, when your CNS packs do not declare a mod's path,
when your PC cannot load the mesh (a DLC you do not own, a mod you lack), or when a leader's mesh has other bones than
the table's. The body falls back to `CH_P_EVE_08` and the hair to `EVE_HR_01`, and each of the fallback's bones follows
her bone with the same name. Another leader whose mesh has other bones is drawn on that mesh the same way, so a head
replacer you lack still shows the original head. A part with no fallback is left out, with the parts that follow it.
`coop basesuit` forces the base suit for the body and hair.

When a part with a mod tag ends up on a fallback or left out, the ghost names the tags once per generation, on screen
in the menu's language (see [Ghost](partner.md#mods-and-cns-outfits)), and in the build line
(`mod parts not shown: ...`).

## 7. Map gate

The ghost is built only when the table's map is the one you are on. Otherwise the log says once
`Ghost hidden: she is on <map>, you are on <map>.`, `coop status` shows `ghost=hidden map`, and the poses that arrive
are counted as foreign. After a level change the ghost is removed. It comes back once your EVE has been in the world
for 2 s and the maps match. A ghost left standing by a Lua reload (Ctrl+R) is found and removed at the next load.

## Looks

The four looks (cloth, dyes, effects, drone) use the same pipeline. Dyes add `material` and `value` lines to the table
(parts on a mod's mesh have them either way). A slot's values go on a dynamic instance the ghost makes of that slot's
material (`CreateDynamicMaterialInstance`, then `SetVectorParameterValue`, `SetScalarParameterValue` and
`SetTextureParameterValue`), and a later table sets only what changed on that instance. A value gone from a later table
puts the slot back on the plain material, and what is left goes on a new instance. A slot with no material here (a
missing pack) gets no values and no error. If the instance or a setter fails, the slot goes back on the plain material
and stays there for this ghost, with one note in the log. Textures load after the build, one each 0.25 s, by the same
rules as meshes. At most 64 wait at once, with one note in the log. Those left over are tried again once none waits. A
Lua load makes at most 1024 FNames for values, since FNames are never freed.

Hide lines go on a part drawn on its own mesh, under the dyes rule. The ghost calls `ShowAllMaterialSections(0)`, then
`ShowMaterialSection(slot, 0, false, 0)` for each slot the mesh has: section 0 and LOD 0, as CNS calls it. They are set
again only when they change. If a call fails, the part shows every slot, with one note in the log. Not tested in game
yet.

Shape keys are not carried. A leader is a PoseableMeshComponent, which has no morph call. A follower follows its
leader through `SetMasterPoseComponent`, and in UE 4.26 `USkeletalMeshComponent::UpdateSlaveComponent` zeroes the
follower's morph weights on every tick, then adds `SetMorphTarget`'s values back only when the leader is a
SkeletalMeshComponent. With a Poseable leader, a follower's shape keys would be cleared before each frame is drawn.
Drawing them would need a SkeletalMeshComponent leader.

Effects fill the pose's six slots, and the native part writes the drawn slots into six boxes beside the mailbox, from
which Lua starts and moves the effects. Effects have their own fault latch, so a fault there turns effects off for the
run and the ghost stays. See [Ghost](partner.md#looks).

Indexes 1 to 19 are `Capture.EFFECTS`, which both sides compile in. Once a second the capture also reads the
NiagaraComponents attached directly to her leader parts (the ones the native read walks, 256 children a part at most)
that are active, and each one's `Asset`. A system outside the list gets the next index from 20 when its path is in the
game's FX folders (`/Game/Art/FX/...`, `/Game/DLC_<n>/Art/FX/...`, the character folders' name rule) or among your CNS
and shared assets (`core/link.lua`'s `mod_assets()`). With `mod_names=off` only game FX paths go, and none your CNS
packs or shared mods name.

An index is never given another path while the same EVE is in the world, and 45 is the cap. A new name publishes the
table again under the same generation, at most once a second. The worker hands the game thread the new `effect`
addresses without a new Live, so her ghost's playback does not restart.

The viewer's ghost loads each named system by the fetch rules above, as a NiagaraSystem: game FX paths as the game's,
the others only from your own CNS and shared lists. The build loads those its table names, a step each; one named later
is loaded by the tick, one each 0.25 s, never while the boxes are read. A slot naming a system not loaded yet is skipped
silently, so the first instance of a new effect does not show on either side. One that fails or is refused draws nothing
on its index, with one note a ghost. Not tested in game yet.

Her drone's free part is a Poseable hung on part 0, with its followers on it. The ghost adds a box beside the mailbox
for it, named on the display file's `free <i> 0x<box>` line. At each pose the native part writes the drone's block
there: location and rotation relative to part 0, scale (shown + 1, light step + 1, 1). Lua's `place()` moves the drone
to it at each new pose and shows it while the box and the table say so, never in Doro mode. A SpotLight on the drone's
`FX_Lens` socket, where her drone's Blueprint (`CH_Drone_BP`) hangs its light, gets the step x 4 as intensity. It is
movable, casts no shadows and has an outer cone of 40 degrees, as in the Blueprint. It is off at step 0 or while the
drone is hidden. A Lua error there hides the drone on that ghost until its next build, with one line. The ghost
stays. With the drone look off, the viewer draws no free part, nor the parts that follow or hang on one. The drone's
light shows on every ghost: a lobby holds at most 7 others, under the spec's cap of the 8 nearest. Not tested in game
yet.

Cloth, on by default, uses only the table's `cloth` line (sent whatever the setting): each PC runs NvCloth on the
ghost's ponytail from the body bones that already arrive (her hair chain `Ab-TL-HairB01` to `HairB09` among them). While
the ghost is shown, its root moves without the engine's teleport flag: a teleport clears the cloth's inertia, and the
strands would hang without trailing. It teleports when the ghost shows again and when it moves more than 2 m in one pose
(a fast travel, a respawn). The cloth simulates only while the ghost is drawn (`VisibilityBasedAnimTickOption` 3):
hidden, off screen or behind a wall for more than 1 s, it costs nothing, and it starts again from the bones when the
ghost is drawn again. The ponytail's cloth part is set up as SB sets up hers: the 18 body bones its collision bodies
hang on (`AdditiveMasterBoneArray`), the collision asset as `OverrideClothPhysicsAsset` (the table's `cloth` line, else
the outfit's `<body mesh>_PonytailPhysicsAsset`), then its leader, then its mesh, which creates the cloth. Each asset is
loaded in a build step of its own: the named one before its part's step, the outfit's after the body's.

## Her sounds, sent

With the sounds look on, your game records the sounds it plays for your EVE and sends each one in an event slot of the
pose. The native part does it in `online/partner/sound.h`, `sound_game.inc` and `sound_worker.inc`.

Seven context hooks mark her events. Each one sits in a vtable slot in `.rdata` and runs the game's own function with
the same arguments:

| Slot | Game function | What it plays |
| --- | --- | --- |
| `0x145c51bb0` | `0x142019370` | SB's footstep notify |
| `0x145c525f0` | `0x1420173d0` | SB's character sound notify |
| `0x145c60d60` | `0x1420286c0` | the start of SB's sound notify state (`USBAnimNotifyState_PlaySound`) |
| `0x145cf6398`, `0x145cf5a40`, `0x145cf5cb0` | `0x1424679c0`, `0x142468d90`, `0x14245cdb0` | the show sound updaters |
| `0x1463c3358` | `0x143fccef0` | the engine's `UAnimNotify_PlaySound` |

A notify is hers when its mesh's owner is your EVE or her drone. A show updater is hers when its stage's main actor is
your EVE, read the way the same-place capture reads a stage. No show updater counts while your game's theater holds a
cutscene or a shared scene plays: scene dialogue is not sent.

The sink sits in the audio component's start slot. `0x1463db320` (UAudioComponent) and `0x145d07e48`
(USBSoundComponent) both hold Play, `0x1440925f0`. When the game starts a sound, the sink records it if one of three
rules holds, checked in this order: one of her context hooks is running (mark), the component's owner is her EVE or her
drone (owner), or the component hangs on one of her parts (attach). The record holds the sound, its class and
attenuation, its volume and pitch, its first 8 int parameters and its place relative to the part it hangs on (her main
mesh when none). A parameter with a float, bool or wave value is left out and counted. Under one mark a later start of
the same component replaces its record: the game's pooled spawn starts a component once before its setup and again
after it.

Each record goes into a ring of 64 for its thread. The game thread has one. SB's logic thread, where the show updaters
also run, has its own. A start on any other thread is only counted. The game thread empties its ring each frame and the
logic thread's only while no logic task runs. Nothing is recorded while no capture goes to the loopback or a member, or
while your game plays a ghost's sounds.

A sound gets an asset key the first time its sound, class, attenuation and parameters come together in a link session.
Its SBA line names them by their paths in the game's name pool: `sound <asset> <class|-> <attenuation|-> <params|->`.
A sound outside the game's own folders is dropped and counted. So is one whose line would pass 512 bytes under key
4096. A class or attenuation outside them goes as `-`. Then the event waits for a slot of the pose ([3. The pose
codec](#3-the-pose-codec)) with its volume and pitch in 1/64 steps, its part and its place. An event on a part the
pose's table no longer has (her drone gone since) goes empty in that pose, since the viewer refuses a whole pose that
carries one.

The worker swaps three sets apart, each all or none: the seven context slots, the two audio slots and the two
world-effect slots ([Her world effects](#her-world-effects)). The context set stays while the sounds look or the
effects look is on, so her world effects keep their marks with sounds off. Each swap is a compare-and-swap from the
game's function, relocated to the loaded image. If one slot of a set holds another value, the slots of that set already
swapped go back, with the line `sounds refused: 0x<slot> holds <value>; nothing of that set swapped, the ghost goes on
without sounds (<set>)`. The other sets stay. With the sounds look off the audio set goes back until it is on again.
At `coop off` and after a fault they go back for the run. A fault in a hook or in the naming turns sounds off with one
`sounds off: fault ...` line. The ghost goes on.

`coop status` shows `sounds=on`, `off`, `refused` or `fault`. Every 60 s `coop-link.log` has `sounds, last 60 s:
captured <n> (mark <n>, owner <n>, attach <n>, other thread <n>), sent <n>, <n> events dropped waiting for a slot, <n>
paths refused, <n> params left out, <n> over 4096 keys, <n> events lost to a full ring`. Sounds and world effects share
the rings and the pose's event slots, so the two counts of events cover both. Not tested in game yet.

## Her sounds, played

The viewer's side is `online/partner/assets.lua` in Lua and `online/partner/play_game.inc` in the native part, with
the gate and the wait in `game/events.h`.

One loader serves every ghost slot. A ghost built with the sounds look on (or the effects look, for effect kinds)
has its slot watched. Each 0.25 s at most, the loader reads the new lines of the slot's `coop-names[-k].txt`. It loads
one path each 0.25 s for all the slots together with `LoadAsset`. A path two slots name loads once. Each object must be
of its kind's class: a sound's asset a SoundBase, its class a SoundClass, its attenuation a SoundAttenuation. A path
outside the game's own `Sound` and `Art` folders is a mod's and loads only when you both have that mod, under the crash
sentinel. A failed load is logged once and not tried again. Once every path of a key is in, the loader appends
`loaded <k> 0x<object> 0x<class> 0x<a|0> 0x<b|0>` to the slot's `coop-loaded[-k].txt`. It checks one cached object a
frame. A collected one is loaded again at the same pace. Each key naming it then gets a new line. Each object is
cached with the class it was checked as, so a path named as a sound and as a sound class is checked as both. When the
ghost goes, its slot is no longer read or loaded for. Its loaded file stays: removing it could race the worker's read
offset. `coop off` removes every slot's loaded file.

The worker reads each slot's loaded file every 250 ms and keeps each key's objects with the int parameters its SBA line
names. Each frame the game thread puts the sound events the ghost's playback reached into that ghost's wait (16 at
most). A key with no loaded objects 200 ms later drops its event. Each event whose key is loaded goes to the gate, which
lets through the nearest first: within 50 m of your EVE, at most 8 a second from one ghost and 32 from all of them,
none while a shared scene plays or your theater holds a cutscene. Nothing plays from a ghost that does not show: one
Lua has not built for its table or has destroyed, one with no pose drawn yet, or one whose actor is hidden (`bHidden`,
byte `+0x58`, bit `0x20`). A hidden ghost's waiting events are dropped at once.

Each admitted sound plays with the calls SB's footstep notify (`0x142019370`) makes, in its order:

| Call | What it does |
| --- | --- |
| `0x1441ff120` | makes the audio component on the ghost's actor (world context and owner), never from SB's pool |
| `0x1441088f0` | places it: the event's offset on her main mesh's drawn place, or on the ghost's part |
| `+0x278`, `+0x2d0` | her sound class and attenuation, when her line named them |
| `0x144094850`, `0x144094900` | her volume and pitch |
| `0x1441090b0` | attaches it to the ghost's part (rules at `0x146e15994`: KeepWorld three times), when hers was |
| `0x1440944c0` | each int parameter, its FName found (never added) through `0x14293dde0` |
| `0x1440925f0` | Play, at 0 s |

A sound is dropped and counted when its object is no longer alive with the class it was loaded as. A part Lua did not
draw (a follower, a part left out) hangs the sound on the ghost's main mesh. These calls run only while
`game_calls_ok()` holds. While they run, the sink of [Her sounds, sent](#her-sounds-sent) records nothing. With the
sounds look off, nothing plays. A fault turns her sounds off on both sides with the `sounds off: fault ...` line.

Every 60 s with any of it, `coop-link.log` has `sounds played, last 60 s: <n> played, <n> far, <n> over a ghost's 8, <n>
over all 32, <n> in a scene, <n> from a hidden ghost, <n> without a name, <n> not loaded`. Not tested in game yet.

## Her world effects

With the effects look on, the Niagara and Cascade effects her game starts for your EVE travel the way her sounds do
([Her sounds, sent](#her-sounds-sent)): same context hooks, same rings, same asset keys and event slots. The effects
look counts as on while your capture names effect lines or a ghost's display names effect boxes. Lua writes neither with
`effects=off`.

Two sinks sit in the start slots:

| Slot | Game function | Class |
| --- | --- | --- |
| `0x145952d08` (vtable `0x145952a98` `+0x270`) | `0x140f309d0`, Activate | UNiagaraComponent |
| `0x14645f648` (vtable `0x14645ed28` `+0x920`) | `0x144390180`, ActivateSystem | UParticleSystemComponent |

SB's spawns at a location, `0x142325990` (Niagara) and `0x142325290` (Cascade), place and scale the component, then call
these slots. A sink records a start under the three rules of the audio sink (mark, owner, attach). It reads the system
at the offset of the capture's `effects` line, or the Cascade template at `+0x578`. It also reads the component's world
X scale, its attach parent, its class and its place relative to the part it hangs on (her main mesh when none). Nothing
is recorded while the capture names no effect line. The game thread skips a Niagara start the pose's six effect slots
already carry, by the effect read's own rule: a component of the capture's Niagara class hung right on one of her
published leaders whose system the capture lists. Every other start goes as an event: one placed in the world, one on a
follower part, a system the capture does not list. Its SBA line is `niagara <asset> - -` or `cascade <asset> - -`.
Its event carries the scale in 1/32 steps.

No decal sink exists. SB starts no decal through a component slot: `0x142324d60` registers the decal and the footstep
notify places it after. Her footprints stay out. Her sword trail is a show key (`SBShowTrailKey`) that neither the
engine's trail notify nor the `bVisibleSwordTrail` byte drives, so trails stay out too.

On the viewer, the effect events a ghost's playback reaches wait in their own wait (16 at most, 200 ms each) while the
ghost has effect boxes. One whose key is loaded plays while the ghost shows and no shared scene plays or your theater
holds a cutscene. No distance cap or rate cap applies. It plays where her game played it, through the call her footstep
notify makes, in the ghost actor's world (`AActor::GetWorld`, `0x143f60200`, at vtable `+0x158`): `0x142325990` with her
scale and 1 for the world pool's auto release, or `0x142325290` with her scale. The effect is placed, never attached.
These calls run only while `game_calls_ok()` holds. While they run, the sinks record nothing.

The world-effect set swaps apart from the sound sets. A refusal logs `world effects refused: 0x<slot> holds <value>;
nothing of that set swapped, the ghost goes on without world effects (world effect starts)`. A fault in a sink, in the
naming or in a play turns world effects off on both sides with one `world effects off: fault ...` line. Her sounds go
on. `coop status` shows `world_effects=on`, `off`, `refused` or `fault`. Every 60 s with any of it, `coop-link.log` has
`world effects, last 60 s: captured <n> (mark <n>, owner <n>, attach <n>, other thread <n>), sent <n>, <n> attached
skipped, <n> paths refused, <n> over 4096 keys; played <n>, <n> not spawned, <n> from a hidden ghost, <n> in a scene,
<n> without a name, <n> not loaded`. "Not spawned" counts a spawn call that gave no component and an effect past 128 in
one frame. Not tested in game yet.

## CNS guard and crash sentinel

The CNS part of the ghost is the work that touches a mod's assets or CNS data: the build step of a part whose mesh path
is a mod's (outside the game's folders, or declared by your CNS packs), a material step with a mod's material, the
material values and the hide lines. It runs under its own `pcall`, apart from the rest of the build. A Lua error there
turns the CNS part off until `coop cns reset` or the next Lua load. The ghost is removed and built again at the next
tick without it: mod meshes and mod materials are not loaded, so those parts fall back to the base suit or are left out
(see [Fallback: the base suit](#6-fallback-the-base-suit)), and no values or hidden slots are set. The log gets one
line, `CNS part of the ghost off until coop cns reset or the next Lua load (<error>): ...`. It does not count as one of
the build's three tries. The link, the shared enemies and the shared quests run in modules of their own and go on.

A `pcall` catches Lua errors only. An access violation inside the engine closes the game: a CNS mesh with no skeleton
did it on 2026-10-31. The crash sentinel (`online/partner/sentinel.lua`) deals with that case at the next load. Before
each engine call with an asset your CNS packs declare, Lua writes `coop-cns-call.txt` with the asset's path and outfit,
and empties the file once the call returns or raises. The calls covered are:

- the asset's lookup and load (`StaticFindObject`, `LoadAsset`, `AssetRegistryHelpers:GetAsset`), with the class and
  skeleton checks;
- `SetSkeletalMesh` with a mod's mesh;
- `SetMaterial` with a mod's material, also when a slot goes back on its plain material;
- `CreateDynamicMaterialInstance` from a mod's material, together with that slot's colour values;
- each `SetTextureParameterValue` (the marker names the texture when it is a mod's, else the slot's material);
- the hide calls on a part drawn on a mod's mesh.

A call inside another call's span keeps the outer marker. Each span costs one small write before and one after. A cached
asset writes nothing, and none of these calls runs each frame. A crash outside every span finds the file empty and sets
nothing aside.

When the next Lua load finds the file not empty, the game died during that call. The asset goes on the set-aside list,
`coop-cns-aside.txt`, and the marker is emptied. The log says `Crash sentinel: the game crashed during a call with the
mod asset <path> (outfit <outfit>). ...`, and one notice names the asset once the co-op UI is up or a save is loaded.
From then on the ghost treats that asset as missing. A mesh falls back like any part your PC cannot load, with `<path>
set aside after a crash (coop cns reset)` in the build line. A material leaves the slot on the mesh's own, and a texture
is skipped. The list's first line is the mod version (`version v0.7.5`), and a load of another version drops the list.
`coop cns reset` empties it and turns the CNS part on again.

The assets of a mod both players have (`coop-shared-assets.txt`) go through the same span, the guard and the
set-aside list, with the container's name in place of the outfit.

Not covered: the native part's bone writes each frame and the render thread's use of a mod's mesh. A crash there leaves
no marker. A crash on another thread during a span would set that span's asset aside by mistake; `coop cns reset` brings
it back. Not tested in game yet.

## Solid partner

With `collide=on` (experimental, on by default, not tested in game yet), `online/partner/puppet.lua` adds one
CapsuleComponent to the ghost the first time the ghost shows. The capsule copies your EVE's movement capsule: its radius
and half height (40 and 95 cm in this build) and its height above her feet (her mesh's offset, 97 cm). It hangs on the
ghost's main mesh with an absolute rotation, so it stays upright. Its object type is your capsule's own (channel 24,
`PawnCollision`, in this build), and it blocks that channel and ignores every other. Your EVE's capsule blocks channel
24, the game's monster capsules ignore it and NPC capsules have another type, so only your EVE meets the ghost. If your
capsule does not block its own type, the ghost's capsule takes WorldDynamic instead, which your capsule blocks. Monster
capsules block WorldDynamic too, so in that case the enemies whose AI runs on your PC stop at the ghost as well; the
build line then says `ours type 1`. The capsule has no overlap events and cannot be stepped on. The ghost's parts, its
name tag and any effect started on it have no collision. A Pawn profile would do nothing, since EVE's capsule ignores
the Pawn channel.

The capsule is QueryOnly while solid, and solid only while no rule opens it. `place()` checks the rules every frame,
right after it moves the root, and calls `SetCollisionEnabled` only when the answer changes:

| Rule | Open while | For |
| --- | --- | --- |
| a | `collide=off`, or the ghost hidden | A hidden ghost never blocks |
| b | the two capsules overlap by more than 1 cm, then until 20 cm past touching | The ghost moves by teleport, so it can only step into your EVE; it lets her through, and her movement pushes her out of an overlap of 1 cm or less |
| c | your feet 60 cm or more apart in height | One EVE on the other's head, on a ladder, or on an elevator that moved in one game only |
| d | your movement mode other than Walking, NavWalking or Falling | Swimming, climbing, ziplines |
| e | 2 s of contact (within 5 cm) with no gap of 0.5 s, then until 50 cm apart | A friend standing in a doorway; a ghost that steps back for a pose does not restart the 2 s |
| g | your friend's vitals missing for 3 s, or down | A downed friend can be reached for a revive |

Rule g applies to a friend's ghost only: a replay and the loopback have no vitals. Rule f, which would tell a dodge from
a run, is not built yet, so a dodge into the ghost stops at it, where it passes through an enemy. The start of each
contact logs one line with your speed, `GetMaxSpeed()`, `MovementMode` and the move's root motion data, to find that
rule in game. The capsule's build line logs your capsule as read, the camera boom's probe channel and the ghost's other
parts with collision on (0 expected). `coop status` counts the capsule's changes by rule (`changes=`).

Nothing goes over the network for it, and neither game's state changes: each PC decides for its own EVE. The ghost
shows your friend about one ping late, so the two PCs never agree on a contact, and nothing depends on them agreeing.
