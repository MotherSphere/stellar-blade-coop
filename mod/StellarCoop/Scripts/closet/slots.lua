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
--   menu   the region of the closet menu that lists it (Slots.MENUS). The "intimate" menu is adult. No setting shows
--          it: closet/wiring.lua builds the menu without adult.
--   glyph  the picture its menu tiles show: closet/ui/icons/<glyph>.png (tools/closet_icons/ renders it). Slots of
--          one kind share one (every tattoo slot shows "tattoo").
-- A left and a right piece have a slot each (EarringL, EarringR). A pair is one item in the L slot that also occupies
-- the R slot. The order of Slots.LIST is the deterministic apply order inside a layer.
local Slots = {}

Slots.FULL_OUTFIT = 'FullOutfit'

-- The menu's tabs, in screen order: {id, adult, beta}. Each is a region that lists its slots. The Colour tab (colour)
-- lists closet/colour.lua's roles instead. The fitting tabs (beta) are labelled "(Beta)".
Slots.MENUS = {
    {'full', false}, {'colour', false}, {'head', false, true}, {'torso', false, true}, {'arms', false, true},
    {'hips', false, true}, {'intimate', true, true}, {'legs', false, true}, {'body', false, true}, {'weapon', false},
}

-- {id, layer, group, kind, menu, glyph}
Slots.LIST = {
    -- Layer 0: the base body and what is painted on it.
    {'BaseBody', 0, 'body', 'body', 'body', 'body'},
    {'SkinSuit', 0, 'body', 'mesh', 'body', 'skin_suit'},
    {'SkinTone', 0, 'body', 'colour', 'body', 'skin_tone'},
    {'TanLines', 0, 'body', 'skin', 'body', 'tan_lines'},
    {'SkinShine', 0, 'body', 'skin', 'body', 'shine'},
    {'Dermal', 0, 'body', 'skin', 'body', 'glow'},          -- body glows and LEDs
    {'TattooFull', 0, 'body', 'skin', 'body', 'tattoo'},
    {'TattooChest', 0, 'body', 'skin', 'torso', 'tattoo'},
    {'TattooStomach', 0, 'body', 'skin', 'torso', 'tattoo'},
    {'TattooBack', 0, 'body', 'skin', 'torso', 'tattoo'},
    {'TattooShoulders', 0, 'body', 'skin', 'torso', 'tattoo'},
    {'TattooUpperArm', 0, 'body', 'skin', 'arms', 'tattoo'},
    {'TattooForearm', 0, 'body', 'skin', 'arms', 'tattoo'},
    {'TattooHand', 0, 'body', 'skin', 'arms', 'tattoo'},
    {'Fingernails', 0, 'body', 'colour', 'arms', 'nails'},
    {'TattooHips', 0, 'body', 'skin', 'hips', 'tattoo'},
    {'TattooLowerBack', 0, 'body', 'skin', 'hips', 'tattoo'},
    {'TattooButt', 0, 'body', 'skin', 'hips', 'tattoo'},
    {'PubicHair', 0, 'body', 'skin', 'intimate', 'curl'},
    {'Anus', 0, 'body', 'body', 'intimate', 'body'},
    {'TattooPubic', 0, 'body', 'skin', 'intimate', 'tattoo'},
    {'TattooThigh', 0, 'body', 'skin', 'legs', 'tattoo'},
    {'TattooCalf', 0, 'body', 'skin', 'legs', 'tattoo'},
    {'TattooFoot', 0, 'body', 'skin', 'legs', 'tattoo'},
    {'Toenails', 0, 'body', 'colour', 'legs', 'nails'},
    -- Layer 1: mid
    {'UndergarmentTop', 1, 'body', 'mesh', 'torso', 'bra'},
    {'UndergarmentBottom', 1, 'body', 'mesh', 'hips', 'underwear'},
    {'Legs', 1, 'body', 'mesh', 'legs', 'legwear'},             -- stockings, socks, leggings
    -- Layer 2: outer
    {'Chest', 2, 'body', 'mesh', 'torso', 'top'},
    {'Pants', 2, 'body', 'mesh', 'hips', 'bottoms'},
    {'Shoes', 2, 'body', 'mesh', 'legs', 'shoes'},
    {'Gloves', 2, 'body', 'mesh', 'arms', 'gloves'},
    {'Sleeves', 2, 'body', 'mesh', 'arms', 'sleeves'},
    {'Belt', 2, 'body', 'mesh', 'hips', 'belt'},
    {'Garter', 2, 'body', 'mesh', 'hips', 'band'},
    {'ThighStraps', 2, 'body', 'mesh', 'legs', 'band'},
    {'Outerwear', 2, 'body', 'mesh', 'torso', 'jacket'},
    {'Cape', 2, 'body', 'mesh', 'torso', 'cape'},
    -- Layer 3: accents and hardware
    {'Collar', 3, 'body', 'mesh', 'torso', 'collar'},
    {'Necklace', 3, 'body', 'mesh', 'torso', 'necklace'},
    {'ChestHardware', 3, 'body', 'mesh', 'torso', 'harness'},   -- harness, straps
    {'NippleL', 3, 'body', 'mesh', 'torso', 'piercing'},
    {'NippleR', 3, 'body', 'mesh', 'torso', 'piercing'},
    {'Navel', 3, 'body', 'mesh', 'torso', 'piercing'},
    {'BraceletL', 3, 'body', 'mesh', 'arms', 'bracelet'},
    {'BraceletR', 3, 'body', 'mesh', 'arms', 'bracelet'},
    {'Rings', 3, 'body', 'mesh', 'arms', 'ring'},
    {'Armbands', 3, 'body', 'mesh', 'arms', 'band'},
    {'ClitPiercing', 3, 'body', 'mesh', 'intimate', 'piercing'},
    {'LabiaPiercing', 3, 'body', 'mesh', 'intimate', 'piercing'},
    {'AnalPlug', 3, 'body', 'mesh', 'intimate', 'jewel'},
    {'AnkletL', 3, 'body', 'mesh', 'legs', 'bracelet'},
    {'AnkletR', 3, 'body', 'mesh', 'legs', 'bracelet'},
    -- Head: survives a FullOutfit.
    {'Face', 3, 'head', 'swap', 'head', 'face'},
    {'Hair', 3, 'head', 'swap', 'head', 'hair'},
    {'Ponytail', 3, 'head', 'swap', 'head', 'ponytail'},
    {'Ears', 3, 'head', 'swap', 'head', 'ears'},
    {'Eyes', 3, 'head', 'colour', 'head', 'eyes'},
    {'Makeup', 3, 'head', 'skin', 'head', 'makeup'},
    {'FaceTattoo', 3, 'head', 'skin', 'head', 'tattoo'},
    {'HairAccessory', 3, 'head', 'mesh', 'head', 'hair_accessory'},
    {'Headwear', 3, 'head', 'mesh', 'head', 'headwear'},
    {'Mask', 3, 'head', 'mesh', 'head', 'mask'},
    {'Glasses', 3, 'head', 'mesh', 'head', 'glasses'},
    {'EarringL', 3, 'head', 'mesh', 'head', 'earring'},
    {'EarringR', 3, 'head', 'mesh', 'head', 'earring'},
    {'BrowPiercing', 3, 'head', 'mesh', 'head', 'piercing'},
    {'NosePiercing', 3, 'head', 'mesh', 'head', 'piercing'},
    {'SeptumPiercing', 3, 'head', 'mesh', 'head', 'piercing'},
    {'LipPiercing', 3, 'head', 'mesh', 'head', 'piercing'},
    {'TonguePiercing', 3, 'head', 'mesh', 'head', 'piercing'},
    {'Weapon', 3, 'weapon', 'swap', 'weapon', 'weapon'},
    -- Override
    {Slots.FULL_OUTFIT, 99, 'override', 'mesh', 'full', 'full_outfit'},
}

-- Anatomical regions of a base or inner mesh (its material slots are named Mat_<Region> by convention).
Slots.REGIONS = {'HeadNeck', 'TorsoUpper', 'TorsoLower', 'Pelvis', 'ArmUpper', 'Forearm', 'Hand', 'Thigh', 'Calf',
    'Foot'}

Slots.BY_ID = {}
for index, entry in ipairs(Slots.LIST) do
    Slots.BY_ID[entry[1]] = {id = entry[1], layer = entry[2], group = entry[3], kind = entry[4], menu = entry[5],
        glyph = entry[6], order = index}
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
function Slots.glyph(id) return Slots.BY_ID[id] and Slots.BY_ID[id].glyph end
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
