-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet: the slot taxonomy. Pure Lua, no engine calls, so tests run offline.
--
-- Every wearable sits in one slot. Slots belong to a layer (0 base, 1 mid, 2 outer, 3 accents and hardware,
-- 99 the FullOutfit override) and to a group: "body" slots are the ones a FullOutfit suppresses, "head" and
-- "weapon" slots survive it. The order of Slots.LIST is the deterministic apply order inside a layer.
local Slots = {}

Slots.FULL_OUTFIT = 'FullOutfit'

-- {id, layer, group}
Slots.LIST = {
    -- Layer 0: base
    {'BaseBody', 0, 'body'},
    {'SkinSuit', 0, 'body'},
    -- Layer 1: mid
    {'UndergarmentTop', 1, 'body'},
    {'UndergarmentBottom', 1, 'body'},
    {'Legs', 1, 'body'},
    -- Layer 2: outer
    {'Chest', 2, 'body'},
    {'Pants', 2, 'body'},
    {'Shoes', 2, 'body'},
    {'Gloves', 2, 'body'},
    {'Belt', 2, 'body'},
    {'Outerwear', 2, 'body'},
    {'Cape', 2, 'body'},
    -- Layer 3: accents and hardware
    {'Neck', 3, 'body'},
    {'Navel', 3, 'body'},
    {'ChestHardware', 3, 'body'},
    {'PelvicHardware', 3, 'body'},
    {'Dermal', 3, 'body'},
    {'Face', 3, 'head'},
    {'Hair', 3, 'head'},
    {'Ponytail', 3, 'head'},
    {'Ears', 3, 'head'},
    {'Eyes', 3, 'head'},
    {'FacePiercings', 3, 'head'},
    {'Weapon', 3, 'weapon'},
    -- Override
    {Slots.FULL_OUTFIT, 99, 'override'},
}

-- Anatomical regions of a base or inner mesh (its material slots are named Mat_<Region> by convention).
Slots.REGIONS = {'HeadNeck', 'TorsoUpper', 'TorsoLower', 'Pelvis', 'ArmUpper', 'Forearm', 'Hand', 'Thigh', 'Calf',
    'Foot'}

Slots.BY_ID = {}
for index, entry in ipairs(Slots.LIST) do
    Slots.BY_ID[entry[1]] = {id = entry[1], layer = entry[2], group = entry[3], order = index}
end

Slots.IS_REGION = {}
for _, region in ipairs(Slots.REGIONS) do Slots.IS_REGION[region] = true end

function Slots.known(id) return Slots.BY_ID[id] ~= nil end
function Slots.layer(id) return Slots.BY_ID[id] and Slots.BY_ID[id].layer end
function Slots.group(id) return Slots.BY_ID[id] and Slots.BY_ID[id].group end
function Slots.order(id) return Slots.BY_ID[id] and Slots.BY_ID[id].order end

-- Sorts slot ids into apply order: layer first, then their place in LIST.
function Slots.sort(ids)
    table.sort(ids, function(a, b) return Slots.order(a) < Slots.order(b) end)
    return ids
end

return Slots
