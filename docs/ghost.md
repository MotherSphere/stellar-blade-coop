# Your friend's ghost

## Looks

Three looks change what the ghost shows. Each is `on` or `off` in `coop-settings.txt`: `cloth` is on by default,
`dyes` and `effects` are off. The file names them in a comment only, so add a line such as `dyes=on` or `cloth=off`,
or change them in the menu's Options > Ghost. A file that already says `cloth=off` keeps it off. `coop look` changes
one until the mod reloads. With one on, the `Ghost ... built` log line ends with `; look: ...`.

The three looks have not been tested in game yet. Back up your saves before you play with one on (see
[saves.md](saves.md)), and turn it off if the game crashes or the ghost looks wrong.

- `cloth`: her ponytail moves as in solo. In solo, the strands you see are an NvCloth simulation of the ponytail mesh,
  pinned at the scalp; the bones that the poses carry only anchor it. Without cloth, the ghost's ponytail follows those
  bones rigidly and looks like one long block. With cloth on, your game runs the same simulation on the ghost's
  ponytail: a follower part whose mesh has clothing assets is drawn as a SkeletalMeshComponent whose cloth simulates on
  its leader's bones, only while the ghost is on screen. It collides with her outfit as in solo: it takes the collision
  asset her ponytail uses (her capture's `cloth` line, a CNS outfit's `PonyPhysics` among them), else the outfit's
  ponytail collision asset (`<body mesh>_PonytailPhysicsAsset`). If your PC lacks both, the build line says
  `outfit collision not used` and the cloth keeps the clothing asset's own collision. Only that asset's path goes over
  the network, whatever the setting. Each PC simulates the ghost it draws, so only the viewer's setting counts, and the
  strands follow the same rules as on her screen without being the same strands. If the cloth part fails, the ponytail
  is a plain part, with a note in the log.
- `dyes`: her hair colour and other material variants. Her capture also names each part's overridden materials (a
  material made at run time is sent as the asset it was made from, with the colours and textures set on it), and the
  ghost puts on each one your PC has, by the same rules as the meshes. Dyes do not apply to a fallback mesh. Off, each
  part has its mesh's own colours, except a part on a mod's mesh, which takes its materials either way (see
  [Mods and CNS outfits](#mods-and-cns-outfits)). Both players need `dyes=on` for a colour on one of the game's own
  meshes, such as a CNS eye colour on the base face: the sender to send it, the viewer to show it. The same goes for
  the material slots a part hides (CNS toggles).
- `effects`: her attack and skill effects. The native part reads which Niagara systems are playing on her parts, at
  most 4 at a time, into four effect slots of each pose. A slot holds an index: one of 19 known effects of EVE's own,
  or one of up to 45 more that her capture names by path. Her capture gives a system such a name when it plays on one
  of her parts with bones (body, hair, weapon) and lies in the game's FX folders (`/Game/Art/FX/` or
  `/Game/DLC_<n>/Art/FX/`), or belongs to a mod you both have in one version (see
  [Mods you both have](#mods-you-both-have)). It looks once a second, so the first time a new effect plays it does not
  reach the ghost. Your game loads each named system once, during the build or one every 0.25 s after it, and a system
  it cannot load or may not load draws nothing, with one note in the log for that ghost. The ghost starts each effect
  on the part it hangs on, moves it with the slot and stops it when the slot changes, at most 8 starts a second. A fault in the native effect read or write turns effects off until the game restarts
  (`effects off: fault ...`), and the ghost stays without them. Every 60 s with any effect activity, an
  `effects, last 60 s:` line counts those started, those over 4, unlisted reads and boxes written.
- `dyes=off` and `effects=off` also stop sending yours, so your friend's ghost of you lacks them too.

## Mods and CNS outfits

Your friend's ghost loads the meshes their capture names. What your game can draw depends on where a mod puts its
files.

A replacer mod puts its files at the path of a game asset, under `/Game/Art/Character/` or
`/Game/DLC_<n>/Art/Character/`. Your game loads its own file at that path: the mod's version if you have the same mod,
the original if you do not. A leader part (one with bones of its own) whose mesh here has other bones than theirs is
drawn on your mesh with each of its bones following theirs of the same name. A head replacer you lack still shows a
head that way: the original head, moved by the bones the two share.

An added-asset mod puts new assets in a folder of its own. CNS outfits use `/Game/OutfitMods/<name>/`, and `HD-ATOOL_P`
uses `/Game/Mods/HD-ATOOL_P/`. Your game looks up a mesh, a material or a ponytail collision asset from such a folder
only when one of your own CNS packs names that exact path. A pack names every `/Game/...` path it gives under
`OutfitPaths`, `Mesh`, `Materials`, `PonyPhysics`, `Textures` and `Value`. The native part reads your
`*.dekcns.json` files under `SB/Content/Paks/~mods` once at start and writes those paths to `coop-cns.txt`. With the
same CNS outfit installed on both PCs, the ghost wears it. A path that none of your packs names is never looked up or
loaded, even when the file is there: a mod that comes without a CNS pack, such as `HD-ATOOL_P`, always falls back.

A part that cannot be drawn on its own mesh falls back: the body to the base suit `CH_P_EVE_08`, the hair to
`EVE_HR_01`, and any other part is left out with the parts that follow it. When such a part comes from a mod's folder,
a notice names the outfit, in the menu's language, once each time their capture changes (an outfit change, or a load
in their game):

`Kaanta wears parts from mods your game cannot load: Foo_Suit, HD-ATOOL_P. They show on the base suit or are left out.`

The name is the outfit's `UniqueFitID` in your friend's CNS pack, else the last of the first two folders of the path
(`HD-ATOOL_P` for `/Game/Mods/HD-ATOOL_P/...`). Up to two names fit, then `(+n)` for the others. `coop basesuit`
gives no notice.

A part on a mod's mesh sends its overridden materials even with `dyes=off`: CNS sets an outfit's materials when it puts
the outfit on, so the mesh's own are not the outfit's. The CNS colours and option textures set on those materials go
with them, and the ghost applies them on a dynamic instance of the material (not tested in game yet). A change to a
colour reaches the ghost within 21 s, without a new ghost. A texture option shows only if your packs declare the same
texture or it is one of the game's own. A slot whose material your PC lacks keeps the mesh's own, with no values and no
error. The slots an outfit hides (`HiddenMats`, and `MaterialToggles` turned off) are hidden on the ghost too, and the
same change delay applies (not tested in game yet). Shape keys (`ShapeKeys`) do not reach the ghost. Her ponytail's
collision asset goes too (the `cloth` look uses it), so a CNS outfit's `PonyPhysics` reaches the ghost.

A mod's added assets are usually missing from the game's cooked asset registry, and UE4SS's `LoadAsset` finds an
asset through that registry. When `LoadAsset` finds nothing for a path your packs name, the ghost tries
`AssetRegistryHelpers:GetAsset`, which loads by path (the way UE4SS's BPModLoaderMod loads mod actors). This step has
not been tested in game yet. The `Ghost ... built` log line says how each mod asset came:
`mod assets: <path> by GetAsset` (or `by LoadAsset`, `in memory`, `missing`), and which outfits were not shown:
`mod parts not shown: <names>`. A path your packs do not name shows as `<path> not declared by your CNS packs or a mod you both have`.

With `mod_names=off` in `coop-settings.txt`, your capture leaves out every path outside the game's own folders: your
friend's ghost of you shows those parts on the base suit or leaves them out, and no folder or outfit name of yours
reaches them.

### Mods you both have

When you and your friend load the same mod container, the ghost may also load that mod's assets, with or without a
CNS pack. The same container means the same `.pak`, `.ucas` and `.utoc` file names and sizes under
`SB/Content/Paks`. At start the native part reads the directory index of each mod's `.utoc` and keeps the `.uasset`
paths under `SB/Content`. Once your friend's mod list arrives, it writes `coop-shared-assets.txt` with the paths of the
containers she has with the same name and hash as yours, and the ghost is built again. Those paths then follow the CNS
rules: loaded as a mod's asset (with the `GetAsset` step above), under the crash sentinel and the CNS guard (see
[When a mod asset fails](#when-a-mod-asset-fails)). The build line names such a path `<path> by GetAsset` and so on,
and the set-aside list names the container where it would name an outfit.

What it needs:

- the same mod, in the same version, on both PCs;
- `mod_names=on` on both PCs (the default). With either side off, the list stays empty;
- a mod that ships a `.utoc`. A mod that is a `.pak` alone gives no paths.

The hash covers file names and sizes, not their contents, and your friend's game states it. Two builds of a mod whose
files have the same sizes count as one version. Your game still loads only paths of your own containers.

GodEmpress (`queen-lite` on Nexus) is an example. Version 4.3.1 adds no Niagara system of its own: the Raven and
Scarlet effects its skills play are the game's own systems under `/Game/Art/FX/Char/Monster/RavenHuman/`,
`/Game/DLC_2/Art/FX/` and EVE's FX folders, so the `effects` look names them by path whether or not you have the mod.
Its animations arrive as bones, mod or not. Its Raven and Scarlet blades are new meshes inside the game's character
folders, so your game draws them only with the mod installed; with the same version on both PCs they also load under
the crash sentinel. What does not reach the ghost from it, as from any skill: effects placed in the world instead of on
her (about a quarter of its effect keys), its Cascade weapon trails, decals, projectiles, the screen effects (post
process, camera shake, time scale) and the weapon fades of its mode switch. None of this has been tested in game yet.

### When a mod asset fails

A Lua error while the ghost sets up a mod's mesh, a mod's material, CNS colours or hidden slots turns its CNS part off.
The ghost is built again at once without mod meshes, mod materials, colours or hidden slots: those parts show on the
base suit or are left out, as for a mod you lack. Everything else goes on: the link, the chat, the shared enemies and
the shared quests. The log says `CNS part of the ghost off until coop cns reset or the next Lua load (<error>)`. The CNS
part comes back with `coop cns reset` or at the next game start or Ctrl+R.

A crash inside the engine cannot be caught that way, so the mod keeps a marker instead. Just before the ghost hands the
engine an asset your CNS packs declare or a mod you both have holds (`coop-shared-assets.txt`), it writes the asset's
path and outfit into `coop-cns-call.txt`, and it empties the file as soon as the call is done. For a mod you both have,
the outfit field holds the mod's container name. If the game crashes during that call, the file is still full at the next start.
The mod then puts that asset on a set-aside list (`coop-cns-aside.txt`), logs `Crash sentinel: the game crashed during a
call with the mod asset <path> (outfit <outfit>)`, and shows one notice:

`The game crashed last time while the ghost used the mod asset SK_Foo. It stays off the ghost until coop cns reset.`

From then on the ghost draws that asset as missing: a mesh on the base suit or left out, a material as the mesh's own, a
texture not set. The build line shows `<path> set aside after a crash (coop cns reset)`. The list is cleared by `coop
cns reset` and when you install another version of the mod. A crash at any other moment leaves the file empty and sets
nothing aside. Neither part has been tested in game yet.

Not carried: shape keys and face morphs, accessories that are static meshes, actors attached to EVE, and parts past 16.
A pose holds about 900 leader bones in all. When her parts have more, the capture leaves out the last leader parts and
their followers until the pose fits, and its log line ends with `<n> leaders left out, over the pose size`.

## Solid partner (experimental)

With `collide=on` (Options > Ghost > Solid partner; off by default, not tested in game yet), your EVE cannot walk
through your friend's ghost, as with an NPC in town. It is your own setting and changes nothing in your friend's game.
Only your EVE is stopped: enemies, NPCs, the camera and attacks pass through the ghost. If a game update changes her
capsule's collision, the mod falls back to a capsule that the enemies run by your PC meet too, and its build line in
`UE4SS.log` says `ours type 1`.

The ghost lets your EVE through:

- once it overlaps her by more than 1 cm, until they are more than 20 cm apart (the ghost shows your friend about one
  ping late, so it can step into you; a smaller overlap stays solid and can move you by up to 1 cm);
- while your feet are 60 cm or more apart in height (one of you on a ledge, a ladder or an elevator);
- while your EVE swims, climbs, rides a zipline or does anything but walk, run or fall;
- after 2 s of contact, until you are 50 cm apart (a friend standing in a doorway);
- while your friend is down, or their vitals have not arrived for 3 s;
- while the ghost is hidden.

A dodge into the ghost stops at it, where it would pass through an enemy. Turn it off in the menu if it gets in your
way (see [troubleshooting.md](troubleshooting.md#stuck-at-a-doorway-with-the-solid-partner)). `coop status` shows
`collide=` on the ghost's line.
