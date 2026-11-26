-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet: the slot taxonomy. Pure Lua, no engine calls, so tests run offline.
--
-- Every wearable sits in one slot. Each slot has:
--   layer  0 base (the body and what is painted on it), 1 mid, 2 outer, 3 accents and hardware, 99 the FullOutfit
--          override. A shown piece hides the body regions that shown pieces on higher layers cover.
--   group  "body" slots are the ones a FullOutfit suppresses; "head" and "weapon" slots survive it.
--   kind   how the piece is made: "mesh" (a component of its own: one of the ghost's parts), "swap" (replaces one of
--          EVE's own meshes: hair, face, ears, weapon), "skin" (painted on the base body: tattoos, makeup, tan),
--          "colour" (a colour on what is there: eyes, nails, skin tone) or "body" (the base body or one of its own
--          details). Only "mesh" costs a ghost part.
--   menu   the region of the closet menu that lists it (Slots.MENUS). The "intimate" menu is adult and off until the
--          player turns it on.
-- A left and a right piece have a slot each (EarringL, EarringR). A pair is one item in the L slot that also occupies
-- the R slot. The order of Slots.LIST is the deterministic apply order inside a layer.
local Slots = {}

Slots.FULL_OUTFIT = 'FullOutfit'

-- The menu's regions, in screen order: {id, adult}.
Slots.MENUS = {
    {'full', false}, {'head', false}, {'torso', false}, {'arms', false}, {'hips', false}, {'intimate', true},
    {'legs', false}, {'body', false}, {'weapon', false},
}

-- {id, layer, group, kind, menu}
Slots.LIST = {
    -- Layer 0: the base body and what is painted on it.
    {'BaseBody', 0, 'body', 'body', 'body'},
    {'SkinSuit', 0, 'body', 'mesh', 'body'},
    {'SkinTone', 0, 'body', 'colour', 'body'},
    {'TanLines', 0, 'body', 'skin', 'body'},
    {'SkinShine', 0, 'body', 'skin', 'body'},
    {'Dermal', 0, 'body', 'skin', 'body'},          -- body glows and LEDs
    {'TattooFull', 0, 'body', 'skin', 'body'},
    {'TattooChest', 0, 'body', 'skin', 'torso'},
    {'TattooStomach', 0, 'body', 'skin', 'torso'},
    {'TattooBack', 0, 'body', 'skin', 'torso'},
    {'TattooShoulders', 0, 'body', 'skin', 'torso'},
    {'TattooUpperArm', 0, 'body', 'skin', 'arms'},
    {'TattooForearm', 0, 'body', 'skin', 'arms'},
    {'TattooHand', 0, 'body', 'skin', 'arms'},
    {'Fingernails', 0, 'body', 'colour', 'arms'},
    {'TattooHips', 0, 'body', 'skin', 'hips'},
    {'TattooLowerBack', 0, 'body', 'skin', 'hips'},
    {'TattooButt', 0, 'body', 'skin', 'hips'},
    {'PubicHair', 0, 'body', 'skin', 'intimate'},
    {'Anus', 0, 'body', 'body', 'intimate'},
    {'TattooPubic', 0, 'body', 'skin', 'intimate'},
    {'TattooThigh', 0, 'body', 'skin', 'legs'},
    {'TattooCalf', 0, 'body', 'skin', 'legs'},
    {'TattooFoot', 0, 'body', 'skin', 'legs'},
    {'Toenails', 0, 'body', 'colour', 'legs'},
    -- Layer 1: mid
    {'UndergarmentTop', 1, 'body', 'mesh', 'torso'},
    {'UndergarmentBottom', 1, 'body', 'mesh', 'hips'},
    {'Legs', 1, 'body', 'mesh', 'legs'},             -- stockings, socks, leggings
    -- Layer 2: outer
    {'Chest', 2, 'body', 'mesh', 'torso'},
    {'Pants', 2, 'body', 'mesh', 'hips'},
    {'Shoes', 2, 'body', 'mesh', 'legs'},
    {'Gloves', 2, 'body', 'mesh', 'arms'},
    {'Sleeves', 2, 'body', 'mesh', 'arms'},
    {'Belt', 2, 'body', 'mesh', 'hips'},
    {'Garter', 2, 'body', 'mesh', 'hips'},
    {'ThighStraps', 2, 'body', 'mesh', 'legs'},
    {'Outerwear', 2, 'body', 'mesh', 'torso'},
    {'Cape', 2, 'body', 'mesh', 'torso'},
    -- Layer 3: accents and hardware
    {'Collar', 3, 'body', 'mesh', 'torso'},
    {'Necklace', 3, 'body', 'mesh', 'torso'},
    {'ChestHardware', 3, 'body', 'mesh', 'torso'},   -- harness, straps
    {'NippleL', 3, 'body', 'mesh', 'torso'},
    {'NippleR', 3, 'body', 'mesh', 'torso'},
    {'Navel', 3, 'body', 'mesh', 'torso'},
    {'BraceletL', 3, 'body', 'mesh', 'arms'},
    {'BraceletR', 3, 'body', 'mesh', 'arms'},
    {'Rings', 3, 'body', 'mesh', 'arms'},
    {'Armbands', 3, 'body', 'mesh', 'arms'},
    {'ClitPiercing', 3, 'body', 'mesh', 'intimate'},
    {'LabiaPiercing', 3, 'body', 'mesh', 'intimate'},
    {'AnalPlug', 3, 'body', 'mesh', 'intimate'},
    {'AnkletL', 3, 'body', 'mesh', 'legs'},
    {'AnkletR', 3, 'body', 'mesh', 'legs'},
    -- Head: survives a FullOutfit.
    {'Face', 3, 'head', 'swap', 'head'},
    {'Hair', 3, 'head', 'swap', 'head'},
    {'Ponytail', 3, 'head', 'swap', 'head'},
    {'Ears', 3, 'head', 'swap', 'head'},
    {'Eyes', 3, 'head', 'colour', 'head'},
    {'Makeup', 3, 'head', 'skin', 'head'},
    {'FaceTattoo', 3, 'head', 'skin', 'head'},
    {'HairAccessory', 3, 'head', 'mesh', 'head'},
    {'Headwear', 3, 'head', 'mesh', 'head'},
    {'Mask', 3, 'head', 'mesh', 'head'},
    {'Glasses', 3, 'head', 'mesh', 'head'},
    {'EarringL', 3, 'head', 'mesh', 'head'},
    {'EarringR', 3, 'head', 'mesh', 'head'},
    {'BrowPiercing', 3, 'head', 'mesh', 'head'},
    {'NosePiercing', 3, 'head', 'mesh', 'head'},
    {'SeptumPiercing', 3, 'head', 'mesh', 'head'},
    {'LipPiercing', 3, 'head', 'mesh', 'head'},
    {'TonguePiercing', 3, 'head', 'mesh', 'head'},
    {'Weapon', 3, 'weapon', 'swap', 'weapon'},
    -- Override
    {Slots.FULL_OUTFIT, 99, 'override', 'mesh', 'full'},
}

-- Anatomical regions of a base or inner mesh (its material slots are named Mat_<Region> by convention).
Slots.REGIONS = {'HeadNeck', 'TorsoUpper', 'TorsoLower', 'Pelvis', 'ArmUpper', 'Forearm', 'Hand', 'Thigh', 'Calf',
    'Foot'}

Slots.BY_ID = {}
for index, entry in ipairs(Slots.LIST) do
    Slots.BY_ID[entry[1]] = {id = entry[1], layer = entry[2], group = entry[3], kind = entry[4], menu = entry[5],
        order = index}
end

Slots.IS_REGION = {}
for _, region in ipairs(Slots.REGIONS) do Slots.IS_REGION[region] = true end

Slots.ADULT_MENU = {}
for _, menu in ipairs(Slots.MENUS) do Slots.ADULT_MENU[menu[1]] = menu[2] end

function Slots.known(id) return Slots.BY_ID[id] ~= nil end
function Slots.layer(id) return Slots.BY_ID[id] and Slots.BY_ID[id].layer end
function Slots.group(id) return Slots.BY_ID[id] and Slots.BY_ID[id].group end
function Slots.order(id) return Slots.BY_ID[id] and Slots.BY_ID[id].order end
function Slots.kind(id) return Slots.BY_ID[id] and Slots.BY_ID[id].kind end
function Slots.menu(id) return Slots.BY_ID[id] and Slots.BY_ID[id].menu end
-- Whether a piece in this slot is a component of its own, one of the ghost's parts.
function Slots.costs_part(id) return Slots.kind(id) == 'mesh' end
-- Whether the slot sits in the adult menu.
function Slots.adult(id) return Slots.ADULT_MENU[Slots.menu(id)] == true end

-- The slot ids of one menu region, in LIST order (its screen order).
function Slots.in_menu(menu)
    local out = {}
    for _, entry in ipairs(Slots.LIST) do
        if entry[5] == menu then out[#out + 1] = entry[1] end
    end
    return out
end

-- Sorts slot ids into apply order: layer first, then their place in LIST.
function Slots.sort(ids)
    table.sort(ids, function(a, b)
        local la, lb = Slots.layer(a), Slots.layer(b)
        if la ~= lb then return la < lb end
        return Slots.order(a) < Slots.order(b)
    end)
    return ids
end

return Slots
