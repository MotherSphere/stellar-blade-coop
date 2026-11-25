-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet: the wardrobe resolver. Pure Lua, no engine calls: it decides what is worn, what shows and which
-- body regions each shown piece must hide. The runtime (Phase 0/4) turns its answer into components and
-- ShowMaterialSection calls.
--
-- An item is a table (manifest.lua builds them):
--   Id               unique text
--   Slot             its primary slot (slots.lua)
--   Occupies         more slots it physically fills (a dress: {'Pants'})
--   HidesSlots       slots whose pieces it hides without taking them off (a long coat: {'Belt'})
--   HidesBodyRegions regions it covers, hidden on every shown piece below its layer (boots: {'Calf','Foot'})
--   KeepsSlots       FullOutfit only: body slots it leaves showing (piercings worn over a full suit)
--
-- Rules, in order:
--   1. Occupancy. An item claims its Slot plus Occupies. Equipping takes off every item that claims any of the
--      same slots ('replace' policy, the default) or refuses and names them ('block' policy).
--   2. FullOutfit. Equipping one takes nothing off: every body-group piece stays worn but is suppressed (not shown)
--      unless the FullOutfit's KeepsSlots names its slot. Head and weapon slots are never touched. Equipping a
--      body-group piece while a FullOutfit is worn takes the FullOutfit off, so the suppressed pieces show again.
--   3. HidesSlots. A piece that is worn and not suppressed hides whatever claims each slot it names. Hidden is not
--      taken off: unequip the coat and the belt shows again. Applied in one pass, so two pieces that hide each
--      other are both hidden and the result never depends on equip order.
--   4. HidesBodyRegions. Each shown piece hides the union of the regions named by shown pieces on a higher layer.
local Slots = require('closet.slots')

local Resolver = {}
Resolver.__index = Resolver

local function list(t) return type(t) == 'table' and t or {} end

local function claims(item)
    local set = {[item.Slot] = true}
    for _, slot in ipairs(list(item.Occupies)) do set[slot] = true end
    return set
end

-- policy: 'replace' (default) or 'block'.
function Resolver.new(options)
    options = options or {}
    assert(options.policy == nil or options.policy == 'replace' or options.policy == 'block', 'bad policy')
    return setmetatable({policy = options.policy or 'replace', worn = {}}, Resolver)
end

-- The worn items, in apply order (layer, then slot order).
function Resolver:items()
    local out = {}
    for _, item in pairs(self.worn) do out[#out + 1] = item end
    table.sort(out, function(a, b)
        local oa, ob = Slots.order(a.Slot), Slots.order(b.Slot)
        if oa ~= ob then return oa < ob end
        return a.Id < b.Id
    end)
    return out
end

-- The worn item that claims a slot, or nil.
function Resolver:in_slot(slot)
    for _, item in pairs(self.worn) do
        if claims(item)[slot] then return item end
    end
    return nil
end

function Resolver:full_outfit()
    for _, item in pairs(self.worn) do
        if item.Slot == Slots.FULL_OUTFIT then return item end
    end
    return nil
end

-- The worn items equipping `item` would take off, in apply order.
function Resolver:conflicts(item)
    local wanted, out = claims(item), {}
    for _, other in ipairs(self:items()) do
        local clash = false
        if other.Id == item.Id then
            clash = true -- equipping the same item again replaces it (a new variant or config)
        else
            for slot in pairs(claims(other)) do
                if wanted[slot] then clash = true break end
            end
        end
        -- A body piece takes the FullOutfit off (rule 2).
        if not clash and other.Slot == Slots.FULL_OUTFIT and Slots.group(item.Slot) == 'body' then
            local occupies_body = false
            for slot in pairs(wanted) do
                if Slots.group(slot) == 'body' then occupies_body = true end
            end
            clash = occupies_body
        end
        if clash then out[#out + 1] = other end
    end
    return out
end

-- Returns true and the items taken off, or false, 'blocked' and the items in the way ('block' policy).
function Resolver:equip(item)
    assert(type(item) == 'table' and type(item.Id) == 'string', 'item needs an Id')
    assert(Slots.known(item.Slot), 'unknown slot ' .. tostring(item.Slot))
    local clashing = self:conflicts(item)
    local others = {}
    for _, other in ipairs(clashing) do
        if other.Id ~= item.Id then others[#others + 1] = other end
    end
    if self.policy == 'block' and #others > 0 then return false, 'blocked', others end
    for _, other in ipairs(clashing) do self.worn[other.Id] = nil end
    self.worn[item.Id] = item
    return true, others
end

-- Takes off the item with this Id, or the one claiming this slot. Returns it, or nil.
function Resolver:unequip(id_or_slot)
    local item = self.worn[id_or_slot] or self:in_slot(id_or_slot)
    if item then self.worn[item.Id] = nil end
    return item
end

function Resolver:clear() self.worn = {} end

-- What to draw: a list in apply order of
--   {item=, shown=bool, why=nil|'suppressed'|'hidden', by=<Id that hid or suppressed it>, regions={sorted}}
-- regions is the body regions this piece must hide (empty for pieces not shown).
function Resolver:resolve()
    local items = self:items()
    local full = self:full_outfit()
    local keeps = {}
    if full then
        for _, slot in ipairs(list(full.KeepsSlots)) do keeps[slot] = true end
    end
    local state, by_id = {}, {}
    for _, item in ipairs(items) do
        local entry = {item = item, shown = true, regions = {}}
        if full and item ~= full and Slots.group(item.Slot) == 'body' and not keeps[item.Slot] then
            entry.shown, entry.why, entry.by = false, 'suppressed', full.Id
        end
        state[#state + 1] = entry
        by_id[item.Id] = entry
    end
    -- Rule 3, one pass over the pieces that are not suppressed.
    for _, hider in ipairs(state) do
        if hider.why ~= 'suppressed' then
            for _, slot in ipairs(list(hider.item.HidesSlots)) do
                local target = self:in_slot(slot)
                local entry = target and by_id[target.Id]
                if entry and target ~= hider.item and entry.why ~= 'suppressed' and entry.why ~= 'hidden' then
                    entry.shown, entry.why, entry.by = false, 'hidden', hider.item.Id
                end
            end
        end
    end
    -- Rule 4.
    for _, entry in ipairs(state) do
        if entry.shown then
            local layer, set = Slots.layer(entry.item.Slot), {}
            for _, other in ipairs(state) do
                if other.shown and Slots.layer(other.item.Slot) > layer then
                    for _, region in ipairs(list(other.item.HidesBodyRegions)) do set[region] = true end
                end
            end
            for _, region in ipairs(Slots.REGIONS) do
                if set[region] then entry.regions[#entry.regions + 1] = region end
            end
        end
    end
    return state
end

-- The worn Ids in apply order, for saving a loadout.
function Resolver:loadout()
    local ids = {}
    for _, item in ipairs(self:items()) do ids[#ids + 1] = item.Id end
    return ids
end

-- Rebuilds a wardrobe from saved Ids. catalog maps Id to item. Returns the wardrobe, the Ids the catalog lacks (a
-- pack uninstalled) and the Ids dropped because a piece later in apply order took their slot (a hand-edited or
-- stale file). Pieces are equipped in apply order with the 'replace' rules, so the FullOutfit (last) suppresses
-- the body pieces before it instead of taking them off.
-- The result never depends on the file's order.
function Resolver.from_loadout(ids, catalog, options)
    local wardrobe, missing, dropped = Resolver.new(options), {}, {}
    local items = {}
    for _, id in ipairs(list(ids)) do
        local item = catalog[id]
        if item and Slots.known(item.Slot) then items[#items + 1] = item else missing[#missing + 1] = id end
    end
    table.sort(items, function(a, b)
        local oa, ob = Slots.order(a.Slot), Slots.order(b.Slot)
        if oa ~= ob then return oa < ob end
        return a.Id < b.Id
    end)
    local replace = Resolver.new({policy = 'replace'})
    for _, item in ipairs(items) do
        local _, removed = replace:equip(item)
        for _, other in ipairs(removed) do dropped[#dropped + 1] = other.Id end
    end
    wardrobe.worn = replace.worn
    return wardrobe, missing, dropped
end

return Resolver
