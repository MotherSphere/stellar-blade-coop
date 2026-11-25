-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet: reads and checks a native *.stellarcloset.json pack (docs/closet/pack-format.md). Pure Lua.
--
-- Manifest.parse(text, source) returns {items=, errors=, warnings=}. Each problem is '<source>: Items[n].Key: why'.
-- An item with an error is left out; the rest of the pack still loads. Unknown keys are warnings, so a newer pack
-- still loads on an older Stellar Closet.
local Json = require('closet.json')
local Slots = require('closet.slots')

local Manifest = {}

Manifest.FORMAT, Manifest.VERSION = 'StellarCloset', 1
Manifest.CHARACTERS = {EVE = true} -- LILY, ADAM, DRONE: later
Manifest.MAX_MATERIAL_INDEX = 63 -- native/src/game/table.h kMaxSlots - 1

local ITEM_KEYS = {Id = true, DisplayName = true, Description = true, CharacterID = true, Slot = true,
    Occupies = true, HidesSlots = true, HidesBodyRegions = true, KeepsSlots = true, Mesh = true, Materials = true,
    RegionMap = true, Requirement = true, Image = true, Texture = true, Regions = true, Color = true}
local TOP_KEYS = {Format = true, FormatVersion = true, Items = true, Author = true, Name = true}

-- /Game/<folders>/<Asset>.<Asset>, the same shape the ghost's asset gate takes
-- (native/src/link/pak_list.h); at most 255 bytes.
function Manifest.soft_ref(path)
    if type(path) ~= 'string' or #path > 255 then return false end
    local folders, asset, object = path:match('^/Game/([%w_/]+)/([%w_]+)%.([%w_]+)$')
    return folders ~= nil and asset == object and not ('/' .. folders .. '/'):find('//', 1, true)
end

local function is_array(v)
    if type(v) ~= 'table' or v == Json.null then return false end
    local n = 0
    for k in pairs(v) do
        if math.type(k) ~= 'integer' or k < 1 then return false end
        n = n + 1
    end
    return n == #v
end

local function is_object(v)
    if type(v) ~= 'table' or v == Json.null then return false end
    return next(v) == nil or not is_array(v)
end

function Manifest.parse(text, source)
    source = source or 'pack'
    local out = {items = {}, errors = {}, warnings = {}}
    local function err(where, why) out.errors[#out.errors + 1] = ('%s: %s: %s'):format(source, where, why) end
    local function warn(where, why) out.warnings[#out.warnings + 1] = ('%s: %s: %s'):format(source, where, why) end

    local doc, problem = Json.decode(text)
    if doc == nil then err('json', problem) return out end
    if not is_object(doc) then err('top', 'must be an object') return out end
    if doc.Format ~= Manifest.FORMAT then err('Format', 'must be "' .. Manifest.FORMAT .. '"') return out end
    if doc.FormatVersion ~= Manifest.VERSION then
        err('FormatVersion', 'must be ' .. Manifest.VERSION .. ' (this Stellar Closet reads version 1)')
        return out
    end
    for key in pairs(doc) do
        if not TOP_KEYS[key] then warn(key, 'unknown key, ignored') end
    end
    if not is_array(doc.Items) or #doc.Items == 0 then err('Items', 'must be a non-empty array') return out end

    local seen = {}
    for n, raw in ipairs(doc.Items) do
        local where = ('Items[%d]'):format(n)
        local bad = false
        local function fail(key, why) err(where .. (key and '.' .. key or ''), why) bad = true end
        if not is_object(raw) then
            fail(nil, 'must be an object')
        else
            for key in pairs(raw) do
                if not ITEM_KEYS[key] then warn(where .. '.' .. key, 'unknown key, ignored') end
            end
            local item = {}
            -- Identity
            if type(raw.Id) ~= 'string' or not raw.Id:match('^[%w_%.%-]+$') or #raw.Id > 64 then
                fail('Id', 'must be 1 to 64 of A-Z a-z 0-9 _ . -')
            elseif seen[raw.Id] then
                fail('Id', 'repeats Items[' .. seen[raw.Id] .. ']')
            else
                seen[raw.Id] = n
                item.Id = raw.Id
            end
            if type(raw.DisplayName) ~= 'string' or raw.DisplayName == '' then fail('DisplayName', 'must be text') end
            item.DisplayName = raw.DisplayName
            if raw.Description ~= nil and type(raw.Description) ~= 'string' then fail('Description', 'must be text') end
            item.Description = raw.Description or ''
            item.CharacterID = raw.CharacterID or 'EVE'
            if not Manifest.CHARACTERS[item.CharacterID] then
                fail('CharacterID', 'only EVE is supported for now')
            end
            -- Slots
            if not Slots.known(raw.Slot) then fail('Slot', 'unknown slot ' .. tostring(raw.Slot)) end
            item.Slot = raw.Slot
            local full = raw.Slot == Slots.FULL_OUTFIT
            local function slot_list(key, check)
                local v = raw[key]
                if v == nil then return {} end
                if not is_array(v) then fail(key, 'must be an array of slots') return {} end
                local copy = {}
                for i, slot in ipairs(v) do
                    if not Slots.known(slot) then
                        fail(key, ('[%d] unknown slot %s'):format(i, tostring(slot)))
                    else
                        local why = check and check(slot)
                        if why then fail(key, ('[%d] %s'):format(i, why)) else copy[#copy + 1] = slot end
                    end
                end
                return copy
            end
            item.Occupies = slot_list('Occupies', function(slot)
                if full then return 'a FullOutfit occupies nothing else (it suppresses the body slots)' end
                if slot == raw.Slot then return 'repeats Slot' end
                if slot == Slots.FULL_OUTFIT then return 'FullOutfit cannot be occupied' end
            end)
            item.HidesSlots = slot_list('HidesSlots', function(slot)
                if slot == Slots.FULL_OUTFIT then return 'FullOutfit cannot be hidden' end
                if slot == raw.Slot then return 'an item cannot hide its own slot' end
            end)
            item.KeepsSlots = slot_list('KeepsSlots', function(slot)
                if not full then return 'only a FullOutfit keeps slots' end
                if Slots.group(slot) ~= 'body' then
                    return 'only body slots are suppressed, so only they can be kept'
                end
            end)
            item.HidesBodyRegions = {}
            if raw.HidesBodyRegions ~= nil then
                if not is_array(raw.HidesBodyRegions) then
                    fail('HidesBodyRegions', 'must be an array of regions')
                else
                    for i, region in ipairs(raw.HidesBodyRegions) do
                        if Slots.IS_REGION[region] then
                            item.HidesBodyRegions[#item.HidesBodyRegions + 1] = region
                        else
                            fail('HidesBodyRegions', ('[%d] unknown region %s'):format(i, tostring(region)))
                        end
                    end
                end
            end
            -- Assets, by the slot's kind: a mesh, swap or body piece names its Mesh; a skin piece paints a Texture
            -- on Regions of the base body; a colour piece is one Color.
            local kind = Slots.kind(raw.Slot)
            local painted = kind == 'skin' or kind == 'colour'
            if painted then
                if raw.Mesh ~= nil then fail('Mesh', 'a ' .. kind .. ' piece has no mesh') end
            elseif not Manifest.soft_ref(raw.Mesh) then
                fail('Mesh', 'must be /Game/<folders>/<Asset>.<Asset>')
            end
            item.Mesh = raw.Mesh
            item.Kind = kind
            if kind == 'skin' then
                if not Manifest.soft_ref(raw.Texture) then
                    fail('Texture', 'must be /Game/<folders>/<Asset>.<Asset>')
                end
                item.Texture = raw.Texture
                item.Regions = {}
                if not is_array(raw.Regions) or #raw.Regions == 0 then
                    fail('Regions', 'must be an array of the regions it paints')
                else
                    for i, region in ipairs(raw.Regions) do
                        if Slots.IS_REGION[region] then item.Regions[#item.Regions + 1] = region
                        else fail('Regions', ('[%d] unknown region %s'):format(i, tostring(region))) end
                    end
                end
            elseif raw.Texture ~= nil or raw.Regions ~= nil then
                fail(raw.Texture ~= nil and 'Texture' or 'Regions', 'only a skin piece paints a texture')
            end
            if kind == 'colour' then
                if type(raw.Color) ~= 'string' or not raw.Color:match('^#%x%x%x%x%x%x$') then
                    fail('Color', 'must be #RRGGBB')
                end
                item.Color = raw.Color
            elseif raw.Color ~= nil then
                fail('Color', 'only a colour piece has a Color')
            end
            item.Materials = {}
            if raw.Materials ~= nil then
                if not is_array(raw.Materials) then
                    fail('Materials', 'must be an array')
                else
                    for i, path in ipairs(raw.Materials) do
                        if path == Json.null or path == '' then
                            item.Materials[i] = false -- keep the mesh's own material in this slot
                        elseif Manifest.soft_ref(path) then
                            item.Materials[i] = path
                        else
                            fail('Materials', ('[%d] must be a soft reference, "" or null'):format(i))
                        end
                    end
                end
            end
            item.RegionMap = {}
            if raw.RegionMap ~= nil then
                if not is_object(raw.RegionMap) then
                    fail('RegionMap', 'must be an object of region: [material indexes]')
                else
                    for region, indexes in pairs(raw.RegionMap) do
                        if not Slots.IS_REGION[region] then
                            fail('RegionMap', 'unknown region ' .. tostring(region))
                        elseif not is_array(indexes) then
                            fail('RegionMap', region .. ' must be an array of material indexes')
                        else
                            local copy = {}
                            for _, index in ipairs(indexes) do
                                local whole = type(index) == 'number' and math.tointeger(index)
                                if not whole or whole < 0 or whole > Manifest.MAX_MATERIAL_INDEX then
                                    fail('RegionMap', ('%s: %s is not a material index 0 to %d'):format(region,
                                        tostring(index), Manifest.MAX_MATERIAL_INDEX))
                                else
                                    copy[#copy + 1] = whole
                                end
                            end
                            item.RegionMap[region] = copy
                        end
                    end
                end
            end
            if raw.Image ~= nil and not Manifest.soft_ref(raw.Image) then fail('Image', 'must be a soft reference') end
            item.Image = raw.Image
            item.Requirement = raw.Requirement or 'None'
            if type(item.Requirement) ~= 'string' then fail('Requirement', 'must be text') end
            if not bad then out.items[#out.items + 1] = item end
        end
    end
    return out
end

-- The material indexes an item must hide for a list of regions (resolver.lua's regions), sorted, each once.
function Manifest.hidden_materials(item, regions)
    local set, out = {}, {}
    for _, region in ipairs(regions) do
        for _, index in ipairs(item.RegionMap and item.RegionMap[region] or {}) do set[index] = true end
    end
    for index in pairs(set) do out[#out + 1] = index end
    table.sort(out)
    return out
end

return Manifest
