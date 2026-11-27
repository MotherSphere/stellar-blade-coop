-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet: read-only importer for outfit packs in the CNS JSON format (*.dekcns.json).
--
-- Clean-room: written only from the format's public documentation
-- (github.com/Dekita/SB-CustomNanosuitSystem-Docs, guides cns-json-setup.md and cns-json-advanced.md) and from
-- how creators' packs are actually written. No DekCNS code is used, read or called. DekCNS need not be
-- installed. Packs are read where the player installed them and never changed, copied or shipped.
--
-- CnsImport.parse(text, source) returns {items=, errors=, warnings=, skipped=}. Each CNS entry becomes one Stellar
-- Closet item:
--   Body (or no FitMeshType)  -> FullOutfit
--   Face, Ears, Eyes, Weapon  -> the same slot
--   Hair                      -> Hair, or Ponytail when MeshSubType is PonyTail (any case)
-- Its variants (OutfitPaths, or OutfitDatas, which wins when it has entries) stay together on the item, as do its
-- UserConfigs. Entries for other characters are skipped (Stellar Closet dresses EVE only for now).
-- A Body outfit's MaterialToggles become PieceHints: a guess, from each toggle's name, at which slot that material
-- slot's piece belongs to. The options page sorts the outfit's pieces into sections by them (closet/ui/model.lua).
-- On the outfit worn whole they give a closet slot to each material slot the hand fit map leaves without one
-- (closet/dress.lua), which the colour layer reads for its role.
local Json = require('closet.json')
local Slots = require('closet.slots')

local CnsImport = {}

CnsImport.ID_PREFIX = 'cns:'

local SLOT_OF = {body = Slots.FULL_OUTFIT, [''] = Slots.FULL_OUTFIT, face = 'Face', ears = 'Ears', eyes = 'Eyes',
    weapon = 'Weapon', hair = 'Hair'}

local KNOWN_KEYS = {UniqueFitID = true, Requirement = true, DisplayName = true, Description = true, FitMeshType = true,
    MeshSubType = true, OutfitTypes = true, OutfitImage = true, OutfitPaths = true, OutfitNames = true,
    OutfitDatas = true, AnimationBP = true, PonyPhysics = true, CharacterID = true, UserConfigs = true}

local USER_CONFIG_KINDS = {'ShapeKeys', 'MaterialToggles', 'ScalarControls', 'VectorControls', 'TextureOptions'}

-- Keyword -> slot, checked in order (first match wins), against a toggle's name in lower case. Order matters:
-- 'nipple piercing' must hit NippleL before a bare 'piercing' falls through, 'plugsuit' must not read as a plug,
-- 'toenail' must not read as a fingernail. A pair (both nipples, both ears) goes in the L slot.
CnsImport.PIECE_WORDS = {
    {'nipple', 'NippleL'}, {'clit', 'ClitPiercing'}, {'labia', 'LabiaPiercing'}, {'navel', 'Navel'},
    {'belly', 'Navel'}, {'plugsuit', 'SkinSuit'}, {'anal plug', 'AnalPlug'}, {'butt plug', 'AnalPlug'},
    {'plug', 'AnalPlug'}, {'septum', 'SeptumPiercing'}, {'tongue', 'TonguePiercing'}, {'nose', 'NosePiercing'},
    {'eyebrow', 'BrowPiercing'}, {'lip piercing', 'LipPiercing'}, {'lip ring', 'LipPiercing'},
    {'lipstick', 'Makeup'}, {'makeup', 'Makeup'}, {'earring', 'EarringL'},
    {'dermal', 'Dermal'}, {'glow', 'Dermal'}, {'leds', 'Dermal'}, {'pubic', 'PubicHair'},
    {'toenail', 'Toenails'}, {'nails foot', 'Toenails'}, {'nail', 'Fingernails'},
    {'tan line', 'TanLines'}, {'tanline', 'TanLines'}, {'oil', 'SkinShine'}, {'tattoo', 'TattooFull'},
    {'choker', 'Collar'}, {'collar', 'Collar'}, {'necklace', 'Necklace'}, {'neck', 'Collar'},
    {'harness', 'ChestHardware'}, {'harnais', 'ChestHardware'}, {'garter', 'Garter'}, {'anklet', 'AnkletL'},
    {'stocking', 'Legs'}, {'tights', 'Legs'}, {'sock', 'Legs'}, {'leggings', 'Legs'},
    {'panties', 'UndergarmentBottom'}, {'panty', 'UndergarmentBottom'}, {'thong', 'UndergarmentBottom'},
    {'boot', 'Shoes'}, {'heel', 'Shoes'}, {'shoe', 'Shoes'}, {'sandal', 'Shoes'}, {'sneaker', 'Shoes'},
    {'glove', 'Gloves'}, {'gauntlet', 'Gloves'}, {'bracer', 'Gloves'}, {'bracelet', 'BraceletL'},
    {'armband', 'Armbands'}, {'sleeve', 'Sleeves'}, {'glasses', 'Glasses'}, {'helmet', 'Headwear'},
    {'crown', 'Headwear'},
    {'bra', 'UndergarmentTop'}, -- after bracer/bracelet, which contain it
    {'belt', 'Belt'}, {'holster', 'Belt'},
    {'cape', 'Cape'}, {'cloak', 'Cape'}, {'scarf', 'Cape'},
    {'jacket', 'Outerwear'}, {'coat', 'Outerwear'}, {'hoodie', 'Outerwear'},
    {'pants', 'Pants'}, {'skirt', 'Pants'}, {'shorts', 'Pants'}, {'bottom', 'Pants'}, {'jeans', 'Pants'},
    {'top', 'Chest'}, {'shirt', 'Chest'}, {'bodice', 'Chest'}, {'corset', 'Chest'}, {'vest', 'Chest'},
}

local function is_array(v)
    if type(v) ~= 'table' or v == Json.null then return false end
    local n = 0
    for k in pairs(v) do
        if math.type(k) ~= 'integer' or k < 1 then return false end
        n = n + 1
    end
    return n == #v
end

local function text(v) return type(v) == 'string' and v or nil end

local function strings(v)
    local out = {}
    if is_array(v) then
        for _, s in ipairs(v) do if type(s) == 'string' and s ~= '' then out[#out + 1] = s end end
    end
    return out
end

-- The slot a toggle's name suggests, or nil.
function CnsImport.piece_slot(name)
    name = (text(name) or ''):lower()
    for _, pair in ipairs(CnsImport.PIECE_WORDS) do
        if name:find(pair[1], 1, true) then return pair[2] end
    end
    return nil
end

-- True for files Stellar Closet may read: any .dekcns.json except the ones that ship with DekCNS itself
-- (CustomNanosuitSystem/Cosmetics/DekCNS-*), which stay out of a clean-room importer. A name without the dot before
-- dekcns (OutfitDekcns.json) counts too. path: relative to ~mods, or to Content\Paks with ~mods\ in front (the DLL's).
function CnsImport.should_read(path)
    local p = (path or ''):gsub('\\', '/'):lower():gsub('^~mods/', '')
    if not p:find('dekcns%.json$') then return false end
    return not p:find('^customnanosuitsystem/cosmetics/dekcns%-')
end

-- Adds one file's items to into ({[UniqueFitID] = item}), each with File = file. parse checks repeats within a file
-- only: an id already in into keeps its first item. Returns a line for each repeat.
function CnsImport.merge(into, items, file)
    local repeats = {}
    for _, item in ipairs(items) do
        local first = into[item.UniqueFitID]
        if first then
            repeats[#repeats + 1] = ('%s: UniqueFitID %s repeats %s, ignored'):format(file, item.UniqueFitID,
                first.File)
        else
            item.File = file
            into[item.UniqueFitID] = item
        end
    end
    return repeats
end

local function variants_of(entry)
    local out = {}
    if is_array(entry.OutfitDatas) and #entry.OutfitDatas > 0 then
        for _, data in ipairs(entry.OutfitDatas) do
            if type(data) == 'table' and text(data.Mesh) then
                local hidden = {}
                if is_array(data.HiddenMats) then
                    for _, i in ipairs(data.HiddenMats) do
                        local n = type(i) == 'number' and math.tointeger(i)
                        if n and n >= 0 then hidden[#hidden + 1] = n end
                    end
                end
                -- Materials: index i+1 is material slot i, so an empty, null or bad entry keeps its place as ''
                -- (closet/dress.lua keeps the mesh's own material there).
                local materials = {}
                if is_array(data.Materials) then
                    for i, m in ipairs(data.Materials) do materials[i] = text(m) or '' end
                end
                out[#out + 1] = {Mesh = data.Mesh, Materials = materials,
                    PonyPhysics = text(data.PonyPhysics) or text(entry.PonyPhysics), HiddenMats = hidden,
                    Parameters = is_array(data.Parameters) and data.Parameters or {}}
            end
        end
    else
        for _, mesh in ipairs(strings(entry.OutfitPaths)) do
            out[#out + 1] = {Mesh = mesh, Materials = {}, PonyPhysics = text(entry.PonyPhysics), HiddenMats = {},
                Parameters = {}}
        end
    end
    local names = strings(entry.OutfitNames)
    for i, v in ipairs(out) do v.Name = names[i] end
    return out
end

local function user_configs(entry)
    local cfg = {}
    local raw = type(entry.UserConfigs) == 'table' and entry.UserConfigs ~= Json.null and entry.UserConfigs or {}
    for _, kind in ipairs(USER_CONFIG_KINDS) do
        cfg[kind] = is_array(raw[kind]) and raw[kind] or {} -- tolerate a missing list (CNS itself would refuse)
    end
    return cfg
end

local function piece_hints(configs)
    local hints = {}
    for _, toggle in ipairs(configs.MaterialToggles) do
        if type(toggle) == 'table' then
            local index = type(toggle.MaterialIndex) == 'number' and math.tointeger(toggle.MaterialIndex)
            local slot = CnsImport.piece_slot(toggle.DisplayName)
            if index and index >= 0 then
                hints[#hints + 1] = {MaterialIndex = index, Name = text(toggle.DisplayName) or '', Slot = slot}
            end
        end
    end
    return hints
end

function CnsImport.parse(text_in, source)
    source = source or 'pack'
    local out = {items = {}, errors = {}, warnings = {}, skipped = {}}
    local function err(where, why) out.errors[#out.errors + 1] = ('%s: %s: %s'):format(source, where, why) end
    local function warn(where, why) out.warnings[#out.warnings + 1] = ('%s: %s: %s'):format(source, where, why) end

    local doc, problem = Json.decode(text_in)
    if doc == nil then err('json', problem) return out end
    local entries = is_array(doc) and doc or {doc} -- the format is an array; a lone object is taken too
    local seen = {}
    for n, entry in ipairs(entries) do
        local where = ('[%d]'):format(n)
        if type(entry) ~= 'table' or entry == Json.null or is_array(entry) then
            err(where, 'not an outfit object')
        else
            for key in pairs(entry) do
                if not KNOWN_KEYS[key] then warn(where .. '.' .. tostring(key), 'unknown key, ignored') end
            end
            local id = text(entry.UniqueFitID)
            local character = (text(entry.CharacterID) or 'EVE'):upper()
            local kind = (text(entry.FitMeshType) or ''):lower()
            local slot = SLOT_OF[kind]
            if slot == 'Hair' and (text(entry.MeshSubType) or ''):lower() == 'ponytail' then slot = 'Ponytail' end
            local variants = variants_of(entry)
            if not id or id == '' then
                err(where, 'no UniqueFitID')
            elseif seen[id] then
                err(where, 'UniqueFitID repeats ' .. seen[id])
            elseif character ~= 'EVE' then
                seen[id] = where
                out.skipped[#out.skipped + 1] = ('%s: %s: %s is for %s'):format(source, where, id, character)
            elseif not slot then
                seen[id] = where
                err(where, 'unknown FitMeshType ' .. tostring(entry.FitMeshType))
            elseif #variants == 0 then
                seen[id] = where
                err(where, 'no mesh (OutfitPaths or OutfitDatas)')
            else
                seen[id] = where
                local configs = user_configs(entry)
                out.items[#out.items + 1] = {
                    Id = CnsImport.ID_PREFIX .. id,
                    Source = 'cns',
                    Pack = source,
                    UniqueFitID = id,
                    DisplayName = text(entry.DisplayName) or id,
                    Description = text(entry.Description) or '',
                    CharacterID = 'EVE',
                    Slot = slot,
                    Requirement = text(entry.Requirement) or 'None',
                    OutfitTypes = strings(entry.OutfitTypes),
                    Image = text(entry.OutfitImage),
                    AnimationBP = text(entry.AnimationBP),
                    Variants = variants,
                    Mesh = variants[1].Mesh, -- the first variant, for code that wants one mesh
                    UserConfigs = configs,
                    PieceHints = slot == Slots.FULL_OUTFIT and piece_hints(configs) or {},
                }
            end
        end
    end
    return out
end

return CnsImport
