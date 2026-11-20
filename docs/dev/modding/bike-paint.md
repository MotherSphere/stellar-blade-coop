# Bike paint

The bike can take a paint for each outfit EVE wears. The paints live in one Lua table, `Paint.BY_MESH` in
`mod/StellarCoop/Scripts/vehicles/bike/paint.lua`. This page says how to add an entry to it. What players see is in
[vehicles/bike.md](../../vehicles/bike.md#paint), how the paint is applied in
[vehicles/bike-internals.md](../../vehicles/bike-internals.md#paint).

## The table

```lua
Paint.BY_MESH={
    ['/Game/Art/Character/PC/CH_P_EVE_IberisCostume/CH_P_EVE_IberisCos.CH_P_EVE_IberisCos']={
        [1]={['Base Color Tint']={0.55,0.05,0.10,1}}},
}
```

An entry's key is the object path of EVE's body mesh, written `/Game/<folders>/<name>.<name>`. Its value maps a
material slot of the bike, 0 to 3, to the vector parameters set on that slot. A parameter takes four numbers (red,
green, blue, alpha), each from 0 to 100000. The example gives Gothic Rose a dark red `Base Color Tint` on slot 1. A
name with a space is written in brackets and quotes, as `['Base Color Tint']`.

## Slots and parameters

The bike's mesh, `Adam_Vehicle_02`, has four material slots:

| Slot | Material instance |
| --- | --- |
| 0 | `MI_Adam_vehicle_02_03` |
| 1 | `MI_Adam_vehicle_02_01` |
| 2 | `MI_Adam_vehicle_02_04` |
| 3 | `MI_Adam_vehicle_02_02` |

The four share one parent material, `MA_AdamVehicle`. Its vector parameters are `EmissiveColor`, `Eye Core HDR Tint`,
`ClearCoatColor`, `Flakecolor`, `ScratchColor`, `AO Tint`, `Emissive Channel`, `GrimeColor`, `Eye Edge Glow Color` and
`Base Color Tint`. A name is 1 to 64 bytes from space to `}`. Those are the bytes the capture sends to other players.
The capture writes a space as `~`, so the table refuses a `~`.

The parent sets `Base Color Tint` to white (1, 1, 1, 1). None of the four material instances changes it. Slot 1's
instance sets `FlakeColorIntencity` (the game's spelling) to 0.066667, so a `Flakecolor` on that slot may barely show.

Nobody has checked in game which part of the bike each slot covers or what each parameter changes. Try a value on one
slot at a time.

## Finding the key

1. Put the outfit on EVE, from the game's wardrobe or with `coop wear` for a cut suit.
2. Type `coop bike status` in the UE4SS console.
3. The line ends with `paint off for <path>`. Copy `<path>` whole: it is the key.

Once the mod runs with the new entry, the same line ends with `paint on for <path>`.

## Limits

- One paint per mesh. Outfits whose colour variants share one mesh share one paint.
- Your parked bike shows its paint on your own screen only. Other players see the paint of the bike you ride when
  `dyes` is on for both of you.

## Checking an entry

From the repository root:

```bash
lua5.4 tests/lua/vehicles/bike/paint_test.lua
```

It prints `paint_test ok` when the table passes `Paint.check`. It also counts the table's entries (1 today), so change
that count in the same commit. In game, a table that fails the check paints nothing. `UE4SS.log` then holds one line,
`[StellarCoop][BK] bike paint table refused: <reason>`.
