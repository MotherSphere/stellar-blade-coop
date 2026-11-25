# `*.stellarcloset.json` — pack format, version 1

A Stellar Closet pack is one JSON file that lists wearable pieces. Put it anywhere under `SB/Content/Paks/~mods/`
next to the pack's `.pak`/`.ucas`/`.utoc`. Comments (`//`, `/* */`) and trailing commas are allowed.

Key names are PascalCase, like CNS's, on purpose. The ghost's asset gate (`native/src/link/pak_list.h`,
`cns_assets()`) already reads `/Game/...` paths under `Mesh` and `Materials`. To show a pack's pieces on a friend's
ghost, it only has to learn the new file extension. It does not know it yet.

## Top level

| Key | Type | Required | Notes |
| --- | --- | --- | --- |
| `Format` | text | yes | Always `"StellarCloset"` |
| `FormatVersion` | number | yes | `1` |
| `Name` | text | no | Pack name for the UI |
| `Author` | text | no | |
| `Items` | array | yes | At least one item |

## Item

| Key | Type | Required | Notes |
| --- | --- | --- | --- |
| `Id` | text | yes | Unique; 1–64 of `A-Z a-z 0-9 _ . -`. Use `author.pack.piece` |
| `DisplayName` | text | yes | |
| `Description` | text | no | |
| `CharacterID` | text | no | `EVE` (default). Others come later |
| `Slot` | text | yes | One slot from the table below |
| `Occupies` | slots | no | Extra slots the piece physically fills (a dress: `["Pants"]`). Not allowed on a `FullOutfit` |
| `HidesSlots` | slots | no | Slots it hides without taking them off (a long coat: `["Belt"]`) |
| `HidesBodyRegions` | regions | no | Regions it covers; hidden on every shown piece on a lower layer |
| `KeepsSlots` | slots | no | `FullOutfit` only: body slots left showing (piercings over a full suit) |
| `Mesh` | soft ref | yes | `/Game/<folders>/<Asset>.<Asset>`, weighted to `CH_P_EVE_01_Skeleton` |
| `Materials` | soft refs | no | One per material slot; `null` or `""` keeps the mesh's own |
| `RegionMap` | object | no | `{"Calf": [3], "Foot": [4]}`: which of this mesh's material slots show each region. Needed on any piece that can be covered (base body, skin suits, stockings, inner layers) |
| `Image` | soft ref | no | Icon texture |
| `Requirement` | text | no | `None` (default) |

Unknown keys load with a warning, so newer packs still work on older versions. A broken item is skipped and named in
the log; the rest of the pack still loads.

## Slots and layers

| Layer | Slots |
| --- | --- |
| 0 base | `BaseBody`, `SkinSuit` |
| 1 mid | `UndergarmentTop`, `UndergarmentBottom`, `Legs` |
| 2 outer | `Chest`, `Pants`, `Shoes`, `Gloves`, `Belt`, `Outerwear`, `Cape` |
| 3 accents | body: `Neck`, `Navel`, `ChestHardware`, `PelvicHardware`, `Dermal` · head: `Face`, `Hair`, `Ponytail`, `Ears`, `Eyes`, `FacePiercings` · `Weapon` |
| override | `FullOutfit` |

A `SkinSuit` that includes skin and should replace the base body declares `"Occupies": ["BaseBody"]`. One that is
worn over the body leaves it alone and lists `HidesBodyRegions` instead.

## Regions

`HeadNeck`, `TorsoUpper`, `TorsoLower`, `Pelvis`, `ArmUpper`, `Forearm`, `Hand`, `Thigh`, `Calf`, `Foot`.
Name a base or inner mesh's material slots `Mat_<Region>` and list them in `RegionMap`.

## The rules (`closet/resolver.lua`)

1. **Occupancy.** A piece claims its `Slot` plus `Occupies`. Equipping takes off whatever claims the same slots.
2. **FullOutfit.** Equipping one takes nothing off. Body-slot pieces stay worn but are not shown, except slots in
   its `KeepsSlots`. Head and weapon slots are untouched. Equipping any body piece takes the FullOutfit off and the
   hidden pieces show again. Imported CNS `Body` outfits become FullOutfits.
3. **HidesSlots.** A shown piece hides whatever claims those slots. Taking it off shows them again.
4. **HidesBodyRegions.** Each shown piece hides the regions named by shown pieces on higher layers, through its
   `RegionMap`.

Pieces apply in layer order, then slot order. The result never depends on the order you equipped things in.

## Layer clearances (for creators)

Build each layer out from the base body by: base 0 mm · skin suit +0.5–1.0 mm · underwear and stockings +1.5 mm ·
pants and tops +2.5–3.5 mm · outerwear and armour +4–6 mm. Do not rely on shrink morphs: the ghost cannot show
them.

## Example

```json
{
  "Format": "StellarCloset",
  "FormatVersion": 1,
  "Name": "Example boots",
  "Items": [
    {
      "Id": "example.boots.knee",
      "DisplayName": "Knee Boots",
      "Slot": "Shoes",
      "HidesBodyRegions": ["Calf", "Foot"],
      "Mesh": "/Game/Mods/ExampleBoots/SK_KneeBoots.SK_KneeBoots"
    }
  ]
}
```
